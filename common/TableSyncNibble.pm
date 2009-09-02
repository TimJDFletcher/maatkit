# This program is copyright 2007-2009 Baron Schwartz.
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
# TableSyncNibble package $Revision$
# ###########################################################################
package TableSyncNibble;
# This package implements a moderately complex sync algorithm:
# * Prepare to nibble the table (see TableNibbler.pm)
# * Fetch the nibble'th next row (say the 500th) from the current row
# * Checksum from the current row to the nibble'th as a chunk
# * If a nibble differs, make a note to checksum the rows in the nibble (state 1)
# * Checksum them (state 2)
# * If a row differs, it must be synced
# See TableSyncStream for the TableSync interface this conforms to.
#
# TODO: a variation on this algorithm and benchmark:
# * create table __temp(....);
# * insert into  __temp(....) select pk_cols, row_checksum limit N;
# * select group_checksum(row_checksum) from __temp;
# * if they differ, select each row from __temp;
# * if rows differ, fetch back and sync as usual.
# * truncate and start over.

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use List::Util qw(max);
use Data::Dumper;
$Data::Dumper::Indent    = 0;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(dbh database table handler nibbler quoter struct
                        parser checksum cols vp chunksize where chunker
                        versionparser possible_keys trim) ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }

   # Sanity check.  The row-level (state 2) checksums use __crc, so the table
   # had better not use that...
   $args{crc_col} = '__crc';
   while ( $args{struct}->{is_col}->{$args{crc_col}} ) {
      $args{crc_col} = "_$args{crc_col}"; # Prepend more _ until not a column.
   }
   MKDEBUG && _d('CRC column will be named', $args{crc_col});

   $args{sel_stmt} = $args{nibbler}->generate_asc_stmt(
      parser   => $args{parser},
      tbl      => $args{struct},
      index    => $args{possible_keys}->[0],
      quoter   => $args{quoter},
      asconly  => 1,
   );

   die "No suitable index found"
      unless $args{sel_stmt}->{index}
         && $args{struct}->{keys}->{$args{sel_stmt}->{index}}->{is_unique};
   $args{key_cols} = $args{struct}->{keys}->{$args{sel_stmt}->{index}}->{cols};

   # Decide on checksumming strategy and store checksum query prototypes for
   # later. TODO: some of this code might be factored out into TableSyncer.
   $args{algorithm} = $args{checksum}->best_algorithm(
      algorithm   => 'BIT_XOR',
      vp          => $args{vp},
      dbh         => $args{dbh},
      where       => 1,
      chunk       => 1,
      count       => 1,
   );
   $args{func} = $args{checksum}->choose_hash_func(
      dbh  => $args{dbh},
      func => $args{func},
   );
   $args{crc_wid}    = $args{checksum}->get_crc_wid($args{dbh}, $args{func});
   ($args{crc_type}) = $args{checksum}->get_crc_type($args{dbh}, $args{func});
   if ( $args{algorithm} eq 'BIT_XOR' && $args{crc_type} !~ m/int$/ ) {
      $args{opt_slice}
         = $args{checksum}->optimize_xor(dbh => $args{dbh}, func => $args{func});
   }

   $args{nibble_sql} ||= $args{checksum}->make_checksum_query(
      dbname    => $args{database},
      tblname   => $args{table},
      table     => $args{struct},
      quoter    => $args{quoter},
      algorithm => $args{algorithm},
      func      => $args{func},
      crc_wid   => $args{crc_wid},
      crc_type  => $args{crc_type},
      opt_slice => $args{opt_slice},
      cols      => $args{cols},
      trim      => $args{trim},
      buffer    => $args{bufferinmysql},
   );
   $args{row_sql} ||= $args{checksum}->make_row_checksum(
      table     => $args{struct},
      quoter    => $args{quoter},
      func      => $args{func},
      cols      => $args{cols},
      trim      => $args{trim},
   );

   $args{state}  = 0;
   $args{nibble} = 0;
   $args{handler}->fetch_back($args{dbh});
   return bless { %args }, $class;
}

# Depth-first: if a nibble is bad, return SQL to inspect rows individually.
# Otherwise get the next nibble.  This way we can sync part of the table before
# moving on to the next part.
sub get_sql {
   my ( $self, %args ) = @_;
   if ( $self->{state} ) {
      return 'SELECT '
         . ($self->{bufferinmysql} ? 'SQL_BUFFER_RESULT ' : '')
         . join(', ', map { $self->{quoter}->quote($_) } @{$self->key_cols()})
         . ', ' . $self->{row_sql} . " AS $self->{crc_col}"
         . ' FROM ' . $self->{quoter}->quote(@args{qw(database table)})
         . ' WHERE (' . $self->__get_boundaries() . ')'
         . ($args{where} ? " AND ($args{where})" : '');
   }
   else {
      my $where = $self->__get_boundaries();
      return $self->{chunker}->inject_chunks(
         database  => $args{database},
         table     => $args{table},
         chunks    => [$where],
         chunk_num => 0,
         query     => $self->{nibble_sql},
         where     => [$args{where}],
         quoter    => $self->{quoter},
      );
   }
}

# Returns a WHERE clause for finding out the boundaries of the nibble.
# Initially, it'll just be something like "select key_cols ... limit 499, 1".
# We then remember this row (it is also used elsewhere).  Next time it's like
# "select key_cols ... where > remembered_row limit 499, 1".  Assuming that
# the source and destination tables have different data, executing the same
# query against them might give back a different boundary row, which is not
# what we want, so each boundary needs to be cached until the 'nibble'
# increases.
sub __get_boundaries {
   my ( $self ) = @_;

   if ( $self->{cached_boundaries} ) {
      MKDEBUG && _d('Using cached boundaries');
      return $self->{cached_boundaries};
   }

   my $q = $self->{quoter};
   my $s = $self->{sel_stmt};
   my $row;
   my $lb; # Lower boundaries
   my $sql;
   if ( $self->{cached_row} && $self->{cached_nibble} == $self->{nibble} ) {
      MKDEBUG && _d('Using cached row for boundaries');
      $row = $self->{cached_row};
   }
   else {
      MKDEBUG && _d('Getting next boundary row');
      ($sql, $lb) = $self->__make_boundary_sql();

      # Check that $sql will use the index chosen earlier in new().
      my $explain_index = $self->__get_explain_index($sql);
      if ( ($explain_index || '') ne $s->{index} ) {
        die 'Cannot nibble table ' . $q->quote($self->{database},$self->{table})
         . " because MySQL chose "
         . ($explain_index ? "the `$explain_index`" : 'no') . ' index'
         . " instead of the `$s->{index}` index";
      }

      $row = $self->{dbh}->selectrow_hashref($sql);
   }

   MKDEBUG && _d($row ? 'Got a row' : "Didn't get a row");
   my $where;
   if ( $row ) {
      # Inject the row into the WHERE clause.  The WHERE is for the <= case
      # because the bottom of the nibble is bounded strictly by >.
      my $i = 0;
      ($where = $s->{boundaries}->{'<='})
         =~ s{([=><]) \?}{"$1 " . $q->quote_val($row->{$s->{scols}->[$i++]})}eg;
   }
   else {
      $where = '1=1';
   }

   if ( $lb ) {
      $where = "($lb AND $where)";
   }

   $self->{cached_row}        = $row;
   $self->{cached_nibble}     = $self->{nibble};
   $self->{cached_boundaries} = $where;

   MKDEBUG && _d('WHERE clause:', $where);
   return $where;
}

sub __make_boundary_sql {
   my ( $self ) = @_;
   my $lb;
   my $q   = $self->{quoter};
   my $s   = $self->{sel_stmt};
   my $sql = 'SELECT '
      . join(',', map { $q->quote($_) } @{$s->{cols}})
      . " FROM " . $q->quote($self->{database}, $self->{table})
      . ($self->{versionparser}->version_ge($self->{dbh}, '4.0.9')
         ? " FORCE" : " USE")
      . " INDEX(" . $q->quote($s->{index}) . ")";
   if ( $self->{nibble} ) {
      # The lower boundaries of the nibble must be defined, based on the last
      # remembered row.
      my $tmp = $self->{cached_row};
      my $i   = 0;
      $lb = $s->{boundaries}->{'>'};
      $lb =~ s{([=><]) \?}
              {"$1 " . $q->quote_val($tmp->{$s->{scols}->[$i++]})}eg;
      $sql .= ' WHERE ' . $lb;
   }
   $sql .= " ORDER BY " . join(',', map { $q->quote($_) } @{$self->{key_cols}})
         . ' LIMIT ' . ($self->{chunksize} - 1) . ', 1';
   MKDEBUG && _d('Lower boundary:', $lb);
   MKDEBUG && _d('Next boundary sql:', $sql);
   return $sql, $lb;
}

sub __get_explain_index {
   my ( $self, $sql ) = @_;
   return unless $sql;
   my $explain;
   eval {
      $explain = $self->{dbh}->selectall_arrayref("EXPLAIN $sql",{Slice => {}});
   };
   if ( $EVAL_ERROR ) {
      MKDEBUG && _d($EVAL_ERROR);
      return;
   }
   MKDEBUG && _d('EXPLAIN key:', $explain->[0]->{key}); 
   return $explain->[0]->{key}
}

sub prepare {
   my ( $self, $dbh ) = @_;
   my $sql = 'SET @crc := "", @cnt := 0';
   MKDEBUG && _d($sql);
   $dbh->do($sql);
   return;
}

sub same_row {
   my ( $self, $lr, $rr ) = @_;
   if ( $self->{state} ) {
      if ( $lr->{$self->{crc_col}} ne $rr->{$self->{crc_col}} ) {
         $self->{handler}->change('UPDATE', $lr, $self->key_cols());
      }
   }
   elsif ( $lr->{cnt} != $rr->{cnt} || $lr->{crc} ne $rr->{crc} ) {
      MKDEBUG && _d('Rows:', Dumper($lr, $rr));
      MKDEBUG && _d('Will examine this nibble before moving to next');
      $self->{state} = 1; # Must examine this nibble row-by-row
   }
}

# This (and not_in_left) should NEVER be called in state 0.  If there are
# missing rows in state 0 in one of the tables, the CRC will be all 0's and the
# cnt will be 0, but the result set should still come back.
sub not_in_right {
   my ( $self, $lr ) = @_;
   die "Called not_in_right in state 0" unless $self->{state};
   $self->{handler}->change('INSERT', $lr, $self->key_cols());
}

sub not_in_left {
   my ( $self, $rr ) = @_;
   die "Called not_in_left in state 0" unless $self->{state};
   $self->{handler}->change('DELETE', $rr, $self->key_cols());
}

sub done_with_rows {
   my ( $self ) = @_;
   if ( $self->{state} == 1 ) {
      $self->{state} = 2;
      MKDEBUG && _d('Setting state =', $self->{state});
   }
   else {
      $self->{state} = 0;
      $self->{nibble}++;
      delete $self->{cached_boundaries};
      MKDEBUG && _d('Setting state =', $self->{state},
         ', nibble =', $self->{nibble});
   }
}

sub done {
   my ( $self ) = @_;
   MKDEBUG && _d('Done with nibble', $self->{nibble});
   MKDEBUG && $self->{state} && _d('Nibble differs; must examine rows');
   return $self->{state} == 0 && $self->{nibble} && !$self->{cached_row};
}

sub pending_changes {
   my ( $self ) = @_;
   if ( $self->{state} ) {
      MKDEBUG && _d('There are pending changes');
      return 1;
   }
   else {
      MKDEBUG && _d('No pending changes');
      return 0;
   }
}

sub key_cols {
   my ( $self ) = @_;
   my @cols;
   if ( $self->{state} == 0 ) {
      @cols = qw(chunk_num);
   }
   else {
      @cols = @{$self->{key_cols}};
   }
   MKDEBUG && _d('State', $self->{state},',', 'key cols', join(', ', @cols));
   return \@cols;
}

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
}

1;

# ###########################################################################
# End TableSyncNibble package
# ###########################################################################
