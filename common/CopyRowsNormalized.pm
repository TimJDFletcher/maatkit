# This program is copyright 2011 Percona Inc.
# Feedback and improvements are welcome.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
# systems, you can issue `man perlgpl' or `man perlartistic' to read these
# licenses.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA.
# ###########################################################################
# CopyRowsNormalized package $Revision$
# ###########################################################################

package CopyRowsNormalized;

{ # package scope
use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# Sub: new
#
# Parameters:
#   %args - Arguments
#
# Required Arguments:
#   src          - Source info hashref with at least a dbh and a tbl from
#                  <Schema::get_table()>.
#   dst          - Destination info hashref with at least a dbh and a tbls
#                  arrayref with tbls from <Schema::get_table()>.
#   ColumnMap    - <ColumnMap> object that maps src->tbl columns to dst->tbls.
#   TableNibbler - <TableNibbler> objecct.
#   Quoter       - <Quoter> object.
#
# Optional Arguments:
#   asc_first  - Ascend only first column of multi-column index (default true).
#   asc_only   - Ascend with > instead of >= (default true).
#   txn_size   - COMMIT after inserting this many rows in each dst table
#                (default 1)
#   print      - Print SQL statements.
#   execute    - Execute SQL statements.
#
# Returns:
#   CopyRowsNormalized object
sub new {
   my ( $class, %args ) = @_;
   my @required_args = qw(src dst ColumnMap TableNibbler Quoter);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($src, $dst, $column_map, $nibbler, $q) = @args{@required_args};

   die "No source table" unless $src->{tbl};
   die "No destination tables" unless $dst->{tbls};

   my $index    = $src->{index}   || 'PRIMARY';
   my $txn_size = $args{txn_size} || 1;

   my $asc = $nibbler->generate_asc_stmt(
      tbl_struct => $src->{tbl}->{tbl_struct},
      index      => $index,
      cols       => $column_map->mapped_columns($src->{tbl}),
      asc_first  => defined $args{asc_first} ? $args{asc_first} : 1,
      asc_only   => defined $args{asc_only}  ? $args{asc_only}  : 1,
   );

   # The first query selects the first N rows from the beginning of the
   # table, hence no WHERE.  The LIMIT is added later.
   my $first_sql   =  "SELECT /*!40001 SQL_NO_CACHE */ "
                   . join(', ', @{$asc->{cols}})
                   . " FROM " . $q->quote(@{$src->{tbl}}{qw(db tbl)})
                   . " FORCE INDEX(`$index`)";

   # The next query selects the next N rows > (asc_only) the previous rows.
   # These ascend params give us the WHERE we need.  The LIMIT is added later.
   my $next_sql = $first_sql;
   $next_sql   .= " WHERE $asc->{where}";

   # Add LIMIT to first and next queries.  This limits how many rows are
   # fetched in each chunk, but more rows can be inserted than fetched if,
   # for example, a column maps to 2 or more tables.
   foreach my $sql ( $first_sql, $next_sql ) {
      $sql .= " LIMIT $txn_size";
      print '-- ', $sql, "\n" if $args{print};
   }

   MKDEBUG && _d('First chunk:', $first_sql);
   MKDEBUG && _d('Next chunk:', $next_sql);
   my $first_sth = $src->{dbh}->prepare($first_sql);
   my $next_sth  = $src->{dbh}->prepare($next_sql);

   # For each destination, we need an INSERT statement.  Inserted values
   # will come from the SELECT statement(s) above.  The ColumnMap tells us
   # which values from the source should be inserted into the given dest.
   foreach my $dst_tbl ( @{$dst->{tbls}} ) {
      my $cols = $column_map->mapped_columns($dst_tbl);
      my $sql  = "INSERT INTO " . $q->quote(@{$dst_tbl}{qw(db tbl)})
               . ' (' . join(', ', @$cols) . ')'
               . ' VALUES (' . join(', ', map { '?' } @$cols) . ')';

      # Append a trace msg so someone looking through binlogs can tell
      # where these inserts originated and what they meant to do.
      $sql .= " /* CopyRowsNormalized "
                    . "src_tbl:$src->{tbl}->{db}.$src->{tbl}->{tbl} "
                    . "txn_size:$txn_size pid:$PID "
                    . ($ENV{USER} ? "user:$ENV{USER} " : "")
                    . "*/";

      MKDEBUG && _d($sql);
      print '-- ', $sql, "\n" if $args{print};
      my $sth = $dst->{dbh}->prepare($sql);
      $dst_tbl->{insert} = { sth => $sth, cols => $cols };

      if ( $args{foreign_keys} ) {
         $dst_tbl->{insert}->{last_insert_id} = _make_last_insert_id_callback(
            tbl  => $dst_tbl,
            cols => { map { $_ => 1 } @$cols },
            %args
         );
      }
   }

   my $start_txn_sth = $dst->{dbh}->prepare('START TRANSACTION');
   my $commit_sth    = $dst->{dbh}->prepare('COMMIT');

   my $self = {
      %args,
      asc           => $asc,
      first_sth     => $first_sth,
      next_sth      => $next_sth,
      asc_cols      => $asc->{scols},  # src tbl columns used for nibbling
      chunkno       => 0,              # incr in _copy_rows_in_chunk()
      start_txn_sth => $start_txn_sth,
      commit_sth    => $commit_sth,
   };

   return bless $self, $class;
}

sub copy {
   my ( $self, %args ) = @_;
   my @required_args = qw();
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   my @asc_cols = @{$self->{asc_cols}};

   # Select first chunk of rows, if any, and copy them.  If there are
   # rows, then $last_row will be defined.  There are no params for
   # execute because the first sql has no ? placeholders.
   my $sth      = $self->{first_sth};
   my $last_row = $self->_copy_rows_in_chunk(sth => $sth);

   # Switch to next sth and while the previous chunk has rows, get
   # the next chunk of rows and copy them.
   $sth->finish();
   $sth = $self->{next_sth};
   while ( $last_row ) {
      MKDEBUG && _d('Last row:', Dumper($last_row));
      $last_row = $self->_copy_rows_in_chunk(
         sth    => $sth,
         params => [ @{$last_row}{@asc_cols} ],
      );
   }

   MKDEBUG && _d('No more rows');
   $sth->finish();

   return;
}

sub _copy_rows_in_chunk {
   my ( $self, %args ) = @_;
   my @required_args = qw(sth);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($sth)  = @args{@required_args};
   my @params = $args{params} ? @{$args{params}} : ();

   my $column_map = $self->{ColumnMap};
   my $dst_dbh    = $self->{dst}->{dbh};
   my $dst_tbls   = $self->{dst}->{tbls};
   my $stats      = $self->{stats};
   my $print      = $self->{print};
   my $execute    = $self->{execute};

   $self->{chunkno}++;   
   $stats->{chunks}++ if $stats;

   MKDEBUG && _d('Fetching rows in chunk', $self->{chunkno}); 
   MKDEBUG && _d($sth->{Statement});
   if ( $print ) {
      print $sth->{Statement}, "\n" if $print;
      print "-- Bind values: "
         . join(', ', map { defined $_ ? $_ : 'NULL' } @params)
         . "\n";
   }
   if ( $execute ) {
      $sth->execute(@params);
   }

   MKDEBUG && _d('Got', $sth->rows(), 'rows');
   return unless $sth->rows();

   # START TRANSACTION
   if ( $self->{start_txn_sth} ) {
      MKDEBUG && _d($self->{start_txn_sth}->{Statement});
      if ( $print ) {
         print $self->{start_txn_sth}->{Statement}, "\n";
      }
      if ( $execute ) {
         $self->{start_txn_sth}->execute();
         $stats->{start_transaction}++ if $stats;
      }
   }

   # Fetch and INSERT rows into destination tables.
   my $inserts = $self->{inserts};
   my $last_row;
   ROW:
   while ( $sth->{Active} && defined(my $row = $sth->fetchrow_hashref()) ) {
      $stats->{rows_selected}++ if $stats;
      INSERT:
      foreach my $dst_tbl ( @$dst_tbls ) {
         my $values = $column_map->map_values(
            dbh => $dst_dbh,
            tbl => $dst_tbl,
            row => $row,
         );

         my $insert = $dst_tbl->{insert};
         MKDEBUG && _d($insert->{sth}->{Statement});
         if ( $print ) {
            print $insert->{sth}->{Statement}, "\n";
            print "-- Bind values: "
               . join(', ', map { defined $_ ? $_ : 'NULL' } @$values)
               . "\n";
         }
         if ( $execute ) {
            $insert->{sth}->execute(@$values);
            $stats->{rows_inserted}++ if $stats;
         }

         if ( my $last_insert_id = $insert->{last_insert_id} ) {
            $dst_tbl->{last_insert_id} = $last_insert_id->(
               %args,
               row => $row,
               sth => $insert->{sth},
            );
            MKDEBUG && _d('Last insert id:',
               Dumper($dst_tbl->{last_insert_id}));
         }

         $last_row = $row;
      }
   }

   # COMMIT
   if ( $self->{commit_sth} ) {
      MKDEBUG && _d($self->{commit_sth}->{Statement});
      if ( $print ) {
         print $self->{commit_sth}->{Statement}, "\n";
      }
      if ( $execute ) {
         $self->{commit_sth}->execute();
         $stats->{commit}++ if $stats;
      }
   }

   return $last_row;
}

sub cleanup {
   my ( $self, %args ) = @_;
   # Nothing to cleanup, but caller is still going to call us.
   return;
}

sub _make_last_insert_id_callback {
   my ( %args ) = @_;
   my @required_args = qw(tbl cols);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($tbl, $cols) = @args{@required_args};
   MKDEBUG && _d('Making callback to get last insert id from table',
      $tbl->{tbl}, $tbl->{tbl});

   my $tbl_pk = $tbl->{tbl_struct}->{keys}->{PRIMARY};
   my ($auto_inc_col)
      = grep { $tbl->{tbl_struct}->{is_autoinc}->{$_} }
        @{$tbl_pk->{cols}};
   MKDEBUG && _d('Auto inc col:', $auto_inc_col);

   my $callback;
   if ( $auto_inc_col ) {
      if ( !$cols->{$auto_inc_col} ) {
         MKDEBUG && _d('Using last insert id');
         $callback = sub {
            my ( %args ) = @_;
            my %last_row_id = (
               $auto_inc_col => $args{sth}->{mysql_insertid},
            );
            return \%last_row_id;
         };
      }
      else {
         MKDEBUG && _d('Using fetched value for auto inc column');
         $callback = sub {
            my ( %args ) = @_;
            my %last_row_id = (
               $auto_inc_col => $args{row}->{$auto_inc_col},
            );
            return \%last_row_id;
         };
      }
   }
   else {
      my @need_pk_cols = grep { !$cols->{$_} } @{$tbl_pk->{cols}};
      if ( @need_pk_cols ) {
         # This probably signals that the column map isn't complete,
         # i.e. there's some dst col that isn't mapped which is needed
         # to get the last insert id.
         warn "Cannot get last insert ID for table $tbl->{db}.$tbl->{tbl} "
            . "because primary key columns "
            . join(', ', map { $need_pk_cols[$_] } 0..($#need_pk_cols-1))
            . ", and $need_pk_cols[-1] "
            . "are not selected and no AUTO_INCREMENT column exists";
      }
      else {
         MKDEBUG && _d('Using fetched values for primary key columns');
         $callback = sub {
            my ( %args ) = @_;
            my %last_row_id
               = map { $_ => $args{row}->{$_} } @{$tbl_pk->{cols}};
            return \%last_row_id;
         };
      }
   }

   return $callback;
}

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
}

} # package scope
1;

# ###########################################################################
# End CopyRowsNormalized package
# ###########################################################################
