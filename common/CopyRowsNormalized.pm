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

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# Sub: new
#
# Parameters:
#   %args - Arguments
#
# Returns:
#   CopyRowsNormalized object
sub new {
   my ( $class, %args ) = @_;
   my @required_args = qw(src dsts ColumnMap TableNibbler);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   # The first query selects the first N rows from the beginning of the
   # table, hence no WHERE.  The LIMIT is added later.
   my @mapped_cols = $column_map->mapped_columns();
   my $first_sql   =  "SELECT /*!40001 SQL_NO_CACHE */ "
                   . join(', ', @mapped_cols)
                   . " FROM " . $q->quote($column_mpa->source_table())
                   . " FORCE INDEX(`$src->{index}`)";

   # The next query selects the next N rows > (asc_only) the previous rows.
   # These ascend params give us the WHERE we need.  The LIMIT is added later.
   my $asc = $nibbler->generate_asc_stmt(
      tbl_struct => $src->{tbl_struct},
      index      => $src->{index},
      cols       => \@mapped_cols,
      asc_first  => defined $args{asc_first} ? $args{asc_first} : 1,
      asc_only   => defined $args{asc_only}  ? $args{asc_only}  : 1,
   );
   my $next_sql = $first_sql .= " WHERE $asc->{where}";

   # Add LIMIT to first and next queries.  The transaction is committed after
   # this many rows have been copied.
   foreach my $sql ( $first_sql, $next_sql ) {
      $sql .= " LIMIT $txn_size";
   }

   MKDEBUG && _d('First rows:', $first_sql);
   MKDEBUG && _d('Next rows:', $next_sql);
   my $first_sth = $src->{dbh}->prepare($first_sql);
   my $next_sth  = $src->{dbh}->prepare($next_sql);

   my @inserts;
   foreach my $dst ( @$dsts ) {
      my @cols = $column_map->columns_mapped_to($dst);
      my @vals = $column_map->values_mapped_to($dst);
      my $sql  = "INSERT INTO " . $q->quote(@{$dst}{qw(db tbl)})
               . ' (' . join(', ', @cols) . ')'
               . ' VALUES (' . join(', ', @vals) . ')';
      MKDEBUG && _d($sql);
      my $sth = $dst->{dbh}->prepare($sql);
      push @inserts, { sth => $sth, slice => \@cols };
   }

   my $self = {
      %args,
      asc       => $asc,
      first_sql => $first_sql,
      next_sql  => $next_sql,
      inserts   => \@inserts,
   };

   return bless $self, $class;
}

sub copy {
   my ( $self, %args ) = @_;
   my @required_args = qw();
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   my $asc = $self->{asc};
   my $sth;       # current sth, first_sth then next_sth
   my $last_row;  # last row of previous chunk

   $sth = $self->{first_sth};
   $sth->execute();
   $last_row = $self->_copy_rows(sth => $sth);

   $sth->finish();
   $sth = $self->{next_sth};

   while ( $last_row ) {
      MKDEBUG && _d('Fetching rows in next chunk');
      $sth->execute(@{$last_row}[@{$asc->{slice}}]);
      $last_row = $self->_copy_rows(sth => $sth);
   }

   MKDEBUG && _d('No more rows');
   $sth->finish();

   return;
}

sub _copy_rows {
   my ( $self, $args ) = @_;
   my @required_args = qw(sth);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($sth) = @args{@required_args}:

   MKDEBUG && _d('Got', $sth->rows(), 'rows');
   return unless $sth->rows();

   my $inserts = $self->{inserts};
   my $last_row;

   ROW:
   while ( $sth->{Active} ) {
      my $row = $sth->fetchrow_hashref();

      INSERT:
      foreach my $insert ( @$inserts ) {
         my @values = @{$row}{@{$insert->{slice}}};
         $insert->{sth}->execute(@values);
      }

      $last_row = $row;
   }

   return $last_row;
}

sub cleanup {
   my ( $self, %args ) = @_;
   # Nothing to cleanup, but caller is still going to call us.
   return;
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
