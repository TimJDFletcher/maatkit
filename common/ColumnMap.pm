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
# denormalized table).  For all columns in the given table, the given <Schema>
# is searched for other tables with identical column names.  It's possible
# for a single column to map to multiple columns in different tables.
#
# A column map is used by selecting mapped columns from the table, then
# inserting columns mapped to the other tables using the mapped column values
# selected.  See the test file or mk-insert-normalized and its test for
# examples.
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
#   tbl    - <Schema::get_table()> to map columns from.
#   Schema - <Schema> object with tables to map tbl columns to.
#
# Returns:
#   ColumnMap object
sub new {
   my ( $class, %args ) = @_;
   my @required_args = qw(tbl Schema);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   my $mapped_columns = _map_columns(%args);

   my $self = {
      %args,
      mapped_columns => $mapped_columns,
   };

   return bless $self, $class;
}

sub _map_columns {
   my ( %args ) = @_;
   my @required_args = qw(tbl Schema);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($tbl, $schema) = @args{@required_args};

   die "No database or table" unless $tbl->{db} && $tbl->{tbl};
   die "No table structure"   unless $tbl->{tbl_struct};

   my @mapped_columns;
   COLUMN:
   foreach my $col ( @{$tbl->{tbl_struct}->{cols}} ) {
      MKDEBUG && _d('Mapping column', $col);

      # First see if the column maps directly, src_tbl.colX -> dst_tbl.colX.
      # It can map to multiple dst tables, however many have an exactly named
      # column.
      my $dst_tbls = $schema->find_column(
         col    => $col,
         ignore => [ $tbl ],  # don't map column to itself
      );
      if ( $dst_tbls && @$dst_tbls ) {
         foreach my $dst_tbl ( @$dst_tbls ) {
            MKDEBUG && _d($tbl->{db}, $tbl->{tbl}, $col, 'maps to',
               $dst_tbl->{db}, $dst_tbl->{tbl}, $col);
            if ( !grep { $col eq $_ } @mapped_columns ) {
               push @mapped_columns, $col;
            }
            $dst_tbl->{value_for}->{$col} = '?';

            if ( $dst_tbl->{fk_struct} ) {
               _map_fk_columns(%args, tbl => $dst_tbl);
            } 

            $dst_tbl->{sorted_mapped_columns} = sort_columns(
               tbl  => $dst_tbl,
               cols => [ keys %{$dst_tbl->{value_for}} ],
            );
         }
      }
      else {
         MKDEBUG && _d('Column', $col, 'does not map');
      }
   }

   return \@mapped_columns;
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


   FK:
   foreach my $fk ( values %$fks ) {
      MKDEBUG && _d('Mapping fk columns in constraint', $fk->{name});

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
         if ( $tbl->{value_for}->{$fk_col} ) {
            MKDEBUG && _d('Foreign key column', $fk_col, 'already mapped to',
               $tbl->{value_for}->{$fk_col});
            next FK_COLUMN;
         }
         MKDEBUG && _d($tbl->{db}, $tbl->{tbl}, $fk_col, 'maps to',
            $parent_tbl->{db}, $parent_tbl->{tbl}, $parent_col);
         $parent_col_for{$fk_col} = $parent_col;

      }
      my $fetch_row_params = {
         tbl        => $parent_tbl,
         where      => 'last_insert_id',
         column_map => \%parent_col_for,
      };

      foreach my $fk_col ( keys %parent_col_for ) {
         $tbl->{value_for}->{$fk_col} = $fetch_row_params;
      }
   }

   return;
}

sub fetch_row {
   my ( $self, %args ) = @_;
   my @required_args = qw(dbh tbl column_map);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($dbh, $tbl, $column_map) = @args{@required_args};
   my $where = $args{where} ? $tbl->{$args{where}} : undef;

   MKDEBUG && _d('Fetching values from', $tbl->{db}, $tbl->{tbl});
   my $sth = $tbl->{fetch_row_sth};
   if ( !$sth ) {
      MKDEBUG && _d('Making sth to fetch row from', $tbl->{db}, $tbl->{tbl});
      my $sql
         = "SELECT "
         . join(', ', map { "$column_map->{$_} AS $_" } sort keys %$column_map)
         . " FROM $tbl->{db}.$tbl->{tbl}"
         . ($where ? " WHERE " . join(' AND', map { "$_=?" } sort keys %$where)
                   : "")
         . " LIMIT 1";
      $sth = $tbl->{fetch_row_sth} = $args{dbh}->prepare($sql);
   }

   MKDEBUG && _d($sth->{Statement});
   my @params = $where ? map { $where->{$_} } sort keys %$where : ();
   $sth->execute(@params);

   my $row = $sth->fetchrow_hashref();
   MKDEBUG && _d('Fetched row:', Dumper($row));

   $sth->finish();
   return $row;
}

sub mapped_columns {
   my ( $self ) = @_;
   my @cols = @{$self->{mapped_columns}};
   return @cols;
}

sub columns_mapped_to {
   my ( $self, $tbl ) = @_;
   die "I need a tbl argument" unless $tbl;
   return $tbl->{sorted_mapped_columns};
}

sub map_values {
   my ( $self, %args ) = @_;
   my @required_args = qw(tbl row);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($tbl, $row) = @args{@required_args};

   my $mapped_cols = $tbl->{value_for};
   die "No values are mapped to $tbl->{db}.$tbl->{tbl}"
      unless $mapped_cols && scalar keys %$mapped_cols;

   COLUMN:
   foreach my $col ( keys %$mapped_cols ) {
      my $val = $mapped_cols->{$col};
      if ( exists $row->{$col} ) {
         MKDEBUG && _d('Column', $col, 'already has a value');
         next COLUMN;
      }
      if ( ref $val ) {
         my $fetched_row = $self->fetch_row(%args, %$val);
         @{$row}{keys %$fetched_row} = values %$fetched_row;
      }
   }

   my $sorted_cols = $tbl->{sorted_mapped_columns};
   my @values      = map { $row->{$_} } @$sorted_cols;
   MKDEBUG && _d('Mapped values:', @values);

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
