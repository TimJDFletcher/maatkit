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
# ColumnMap package $Revision$
# ###########################################################################

# Package: ColumnMap
# ColumnMap maps columns from one table to other tables.  A column map helps
# decompose a table into serveral other tables (for example, normalizing a
# denormalized table).  For all columns in the given source table, the given
# <Schema> is searched for other tables with identical column names.  It's
# possible for a single column to map to multiple columns in different tables.
#
# A column map is used by selecting mapped columns from the source table, then
# inserting mapped columns into the destination tables using mapped values.
# See the test file or mk-insert-normalized and its test for examples.
package ColumnMap;

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
#   src_tbl - <Schema::get_table()> to map columns from.
#   Schema  - <Schema> object with tables to map tbl columns to.
#
# Optional Arguments:
#   constant_values - Hashref of constant values, keyed on column name.
#   print           - Print column map.
#
# Returns:
#   ColumnMap object
sub new {
   my ( $class, %args ) = @_;
   my @required_args = qw(src_tbl Schema);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   _map_columns(%args);

   my $self = {
      %args,
   };

   return bless $self, $class;
}

sub _map_columns {
   my ( %args ) = @_;
   my @required_args = qw(src_tbl Schema);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($src_tbl, $schema) = @args{@required_args};

   die "No database or table" unless $src_tbl->{db} && $src_tbl->{tbl};
   die "No table structure"   unless $src_tbl->{tbl_struct};

   foreach my $src_col ( @{$src_tbl->{tbl_struct}->{cols}} ) {
      MKDEBUG && _d('Mapping column', $src_col);
      _map(%args, src_col => $src_col);
   }

   if ( my $const_vals = $args{constant_values} ) {
      foreach my $const_col ( keys %$const_vals ) {
         MKDEBUG && _d('Mapping constant column', $const_col);
         _map(%args, src_col => $const_col, val => $const_vals->{$const_col});
      }
   }

   return;
}

sub _map {
   my ( %args ) = @_;
   my @required_args = qw(src_tbl src_col Schema);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($src_tbl, $src_col, $schema) = @args{@required_args};
   my $val = $args{val};

   # See if the column maps directly, src_tbl.colX -> dst_tbl.colX.
   # One source column can map to multiple destination tables.
   my $dst_tbls = $schema->find_column(
      col    => $src_col,
      ignore => [ $src_tbl ],
   );

   if ( !$dst_tbls || !@$dst_tbls ) {
      MKDEBUG && _d('Column', $src_col, 'does not map');
      return;
   }

   foreach my $dst_tbl ( @$dst_tbls ) {
      # Source col maps to dest col with the same name.  Hopefully this
      # dest column is only mapped to once, else that's a problem that
      # we don't detect yet.  A hash is used to maintain a unique list.
      $dst_tbl->{mapped_columns}->{$src_col}++;

      if ( defined $val ) {
         MKDEBUG && _d($src_tbl->{db}, $src_tbl->{tbl}, $src_col,
            'maps to constant value', $val);
         $dst_tbl->{value_for}->{$src_col} = $val;
         if ( $args{print} ) {
            print "-- Column $src_tbl->{db}.$src_tbl->{tbl}.$src_col "
                . "maps to constant value $val\n";
         }
      }
      else {
         MKDEBUG && _d($src_tbl->{db}, $src_tbl->{tbl}, $src_col,
            'maps to value from',
            $dst_tbl->{db}, $dst_tbl->{tbl}, $src_col);
         # We don't need to set $dst_tbl->{value_for} in this case because
         # the value will come from same column name in the source table
         # which will be $row->{$src_col} in map_values().
         if ( $args{print} ) {
            print "-- Column $src_tbl->{db}.$src_tbl->{tbl}.$src_col "
                . "maps to column "
                . "$dst_tbl->{db}, $dst_tbl->{tbl}, $src_col\n";
         }
      }

      # If the dest table has any fk columns, we must map them all to
      # satisfy the fk contraints.
      if ( $dst_tbl->{fk_struct} ) {
         _map_fk_columns(%args, tbl => $dst_tbl);
      } 
   }

   # This source column has been mapped.  It may be mapped multiple times.
   # A hash is used to maintain a unique list.
   $src_tbl->{mapped_columns}->{$src_col}++;

   return;
}

sub _map_fk_columns {
   my ( %args ) = @_;
   my @required_args = qw(tbl Schema);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($tbl, $schema) = @args{@required_args};

   my $fks = $tbl->{fk_struct};
   return unless $fks;

   # Each fk constraint essentially maps fk columns in the source table
   # to parent columns.  For example,
   #   CONSTRAINT foo FOREIGN KEY            (fk_col1, fk_col2)
   #                  REFERENCES  parent_tbl (p_col1,  p_col2)
   # Column dst_tbl.fk_col1 is mapped/constrained to parent_tbl.p_col1.
   # So we must preserve these mappings/contraints, else the caller won't
   # have all the necessary values to insert rows into the dest tables.
   FK_CONSTRAINT:
   foreach my $fk ( values %$fks ) {
      MKDEBUG && _d('Mapping fk columns in constraint', $fk->{name});

      # TableParser::get_fks() should handle this, but just in case...
      if ( !$fk->{parent_tbl}->{db} ) {
         MKDEBUG && _d('No fk parent table database,',
            'assuming child table database', $tbl->{db});
         $fk->{parent_tbl}->{db} = $tbl->{db};
      }
      my $parent_tbl = $schema->get_table(@{$fk->{parent_tbl}}{qw(db tbl)}); 

      my @fk_cols     = @{$fk->{cols}};
      my @parent_cols = @{$fk->{parent_cols}};
      my %parent_col_for;
      FK_COLUMN:
      for my $i ( 0..$#fk_cols ) {
         my $fk_col     = $fk_cols[$i];
         my $parent_col = $parent_cols[$i];

         # A fk col may already be mapped for two reasons.  One, a previous
         # fk constraint used the column too, so its value will be fetched
         # as part of that previous fk constraint.  Two, the source table has
         # a column with the same name, so _map_columns() already mapped this
         # fk column.  This means that part of this fk constraint comes from
         # the source table and part from the parent table.
         if ( $tbl->{value_for}->{$fk_col} ) {
            MKDEBUG && _d('Foreign key column', $fk_col, 'already mapped to',
               $tbl->{value_for}->{$fk_col});
            next FK_COLUMN;
         }

         MKDEBUG && _d($tbl->{db}, $tbl->{tbl}, $fk_col, 'maps to',
            $parent_tbl->{db}, $parent_tbl->{tbl}, $parent_col);
         $parent_col_for{$fk_col} = $parent_col;
         if ( $args{print} ) {
            print "-- Foreign key column $tbl->{db}.$tbl->{tbl}.$fk_col "
                . "maps to column "
                . "$parent_tbl->{db}.$parent_tbl->{tbl}.$parent_col\n";
         }
      }

      # Fetching parent table column values for fk constraints is like any
      # other type of fetch back.  _fetch_row() uses these params to construct
      # a SELECT statement.  The where value is a key in the tbl hashref that
      # doesn't exist yet, which is why we pass the key.
      my $fetch_row_params = {
         cols  => \%parent_col_for,
         tbl   => $parent_tbl,
         where => 'last_insert_id',
      };

      foreach my $fk_col ( keys %parent_col_for ) {
         $tbl->{mapped_columns}->{$fk_col}++;
         $tbl->{value_for}->{$fk_col} = $fetch_row_params;
      }
   }

   return;
}

sub _fetch_row {
   my ( $self, %args ) = @_;
   my @required_args = qw(dbh fetch_row_params);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($dbh, $params) = @args{@required_args};
   my $tbl            = $params->{tbl};
   my $where          = $tbl->{$params->{where}};
   MKDEBUG && _d('Fetching row from', $tbl->{db}, $tbl->{tbl});

   my $sth = $tbl->{fetch_row_sth} ||= $self->_make_fetch_row_sth(%args);
   MKDEBUG && _d($sth->{Statement});

   my @params = $where ? map { $where->{$_} } sort keys %$where : ();
   print $sth->{Statement}, "\n" if $self->{print};
   $sth->execute(@params);

   my $row = $sth->fetchrow_hashref();
   MKDEBUG && _d('Fetched row:', Dumper($row));

   $sth->finish();
   return $row;
}

sub _make_fetch_row_sth {
   my ( $self, %args ) = @_;
   my @required_args = qw(dbh fetch_row_params);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($dbh, $params) = @args{@required_args};
   my ($cols, $tbl)   = @{$params}{qw(cols tbl where)};
   my $where          = $tbl->{$params->{where}};
   MKDEBUG && _d('Making fetch row sth for', $tbl->{db}, $tbl->{tbl});

   my $sql
      = "SELECT "
      . join(', ', map { "$cols->{$_} AS $_" } sort keys %$cols)
      . " FROM $tbl->{db}.$tbl->{tbl}"
      . ($where ? " WHERE " . join(' AND', map { "$_=?" } sort keys %$where)
                : "")
      . " LIMIT 1";

   my $sth = $args{dbh}->prepare($sql);
   return $sth;
}

sub mapped_columns {
   my ( $self, $tbl ) = @_;
   die "I need a tbl argument"
      unless $tbl;
   die "No mapped columns for table $tbl->{db}.$tbl->{tbl}"
      unless $tbl->{mapped_columns};

   if ( !$tbl->{mapped_columns_sorted} ) {
      $tbl->{mapped_columns_sorted} = sort_columns(
         tbl  => $tbl,
         cols => [ keys %{$tbl->{mapped_columns}} ],
      );
   }
   return $tbl->{mapped_columns_sorted};
}

sub mapped_values {
   my ( $self, $tbl ) = @_;
   my $mapped_cols = $self->mapped_columns($tbl);
   my $value_for   = $tbl->{value_for};
   my @vals        = map { $value_for->{$_} || '?' } @$mapped_cols;
   return \@vals;
}

sub map_values {
   my ( $self, %args ) = @_;
   my @required_args = qw(tbl row);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($tbl, $row) = @args{@required_args};

   my $mapped_cols = $self->mapped_columns($tbl);
   my $value_for   = $tbl->{value_for};
   COLUMN:
   foreach my $col ( @$mapped_cols ) {
      my $val = $value_for->{$col};
      if ( exists $row->{$col} ) {
         MKDEBUG && _d('Value for', $col, 'already exists');
         next COLUMN;
      }

      if ( ref $val ) {
         MKDEBUG && _d('Value for', $col, 'is a fetched row');
         my $fetched_row = $self->_fetch_row(%args, fetch_row_params => $val);
         @{$row}{keys %$fetched_row} = values %$fetched_row;
      }
      else {
         MKDEBUG && _d('Value for', $col, 'is constant');
         $row->{$col} = $val;
      }
   }

   my @values = map { $row->{$_} } @$mapped_cols;
   MKDEBUG && _d("Mapped values:\n",
      map { "$_=" . (defined $row->{$_} ? $row->{$_} : 'undef') . "\n" }
      @$mapped_cols);

   return \@values;
}

# Sub: sort_columns
#   Sort columns based on their real order in the table.
#
# Parameters:
#   %args - Arguments.
#
# Required Arguments:
#   tbl  - <Schema::get_table()> hashref.
#   cols - Arrayref of columns in tbl to sort.
#
# Returns:
#   Array of sorted column names.
sub sort_columns {
   my ( %args ) = @_;
   my @required_args = qw(tbl cols);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $col_pos = $args{tbl}->{tbl_struct}->{col_posn};
   my $cols    = $args{cols};

   my @sorted_cols
      = sort { $col_pos->{$a} <=> $col_pos->{$b} } 
        grep { defined $col_pos->{$_}            }
        @$cols;

   return \@sorted_cols;
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
# End ColumnMap package
# ###########################################################################
