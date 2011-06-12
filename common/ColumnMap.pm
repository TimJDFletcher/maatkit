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
      my $dsts = $schema->find_column(
         col    => $col,
         ignore => [ $tbl ],  # don't map column to itself
      );
      if ( $dsts && @$dsts ) {
         foreach my $dst ( @$dsts ) {
            MKDEBUG && _d($tbl->{db}, $tbl->{tbl}, $col, 'maps to',
               $dst->{db}, $dst->{tbl}, $col);
            if ( !grep { $col eq $_ } @mapped_columns ) {
               push @mapped_columns, $col;
            }
            push @{$dst->{mapped}->{columns}}, $col;
            push @{$dst->{mapped}->{values}}, '?';
      
            if ( $dst->{fk_struct} ) {
               foreach my $fk ( values %{$dst->{fk_struct}} ) {
                  foreach my $fk_col ( @{$fk->{cols}} ) {
                     if (!grep { $fk_col eq $_ } @{$dst->{mapped}->{columns}}) {
                        MKDEBUG && _d('Column', $fk_col, 'needs a fetch back');
                        my $fetch_back = _make_fetch_back(
                           %args,
                           tbl => $dst,
                           fk  => $fk,
                        );
                        push @{$dst->{mapped}->{columns}}, $fk_col;
                        push @{$dst->{mapped}->{values}}, $fetch_back;
                     }
                  }
               }
            }

         }
      }

      else {
         MKDEBUG && _d('Column', $col, 'does not map');
      }
   }

   return \@mapped_columns;
}

sub _is_fk_column {
   my ( %args ) = @_;
   my @required_args = qw(tbl col);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($tbl, $col) = @args{@required_args};
   MKDEBUG && _d('Checking if', $col, 'references a foreign key');

   my $fk;
   if ( $tbl->{fk_struct} ) {
      foreach my $fk ( values %{$tbl->{fk_struct}} ) {
         foreach my $fk_col ( @{$fk->{cols}} ) {
            MKDEBUG && _d('foo:', $fk_col);
            if ( $fk_col eq $col ) {
               MKDEBUG && _d('Column', $col, 'references foreign key',
                  Dupmer($fk));
               return $fk;
            }
         }
      }
   }

   return $fk;
}

sub _make_fetch_back {
   my ( %args ) = @_;
   my @required_args = qw(tbl fk Schema);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($tbl, $fk, $schema) = @args{@required_args};
   MKDEBUG && _d('Making fetch back');

   my $sth;
   my @cols;
   my $fetch_back = sub {
      my ( %args ) = @_;
      MKDEBUG && _d('Fetching row from parent table');
      my $parent_tbl = $schema->get_table(
         $fk->{parent_tbl}->{db} || $tbl->{db},
         $fk->{parent_tbl}->{tbl}
      );
      die "No last insert id for table "
         . ($fk->{parent_tbl}->{db} || $tbl->{db})
         . ".$fk->{parent_tbl}->{tbl}"
         unless $parent_tbl->{last_insert_id};
      @cols = sort keys %{$parent_tbl->{last_insert_id}};
      if ( !$sth ) {
         my $sql = "SELECT " . join(', ', @{$fk->{parent_cols}}) . " FROM "
                 . ($fk->{parent_tbl}->{db} || $tbl->{db})
                 . ".$fk->{parent_tbl}->{tbl}"
                 . " WHERE " . join(' AND', map { "$_=?" } @cols);
         $sth = $args{dbh}->prepare($sql);
      }
      MKDEBUG && _d($sth->{Statement});
      $sth->execute(@{$parent_tbl->{last_insert_id}}{@cols});
      my $row = $sth->fetchrow_arrayref();
      MKDEBUG && _d('Parent row:', Dumper($row));
      $sth->finish();
      return @$row;
   };
   return $fetch_back;
}

sub mapped_columns {
   my ( $self ) = @_;
   my @cols = @{$self->{mapped_columns}};
}

sub columns_mapped_to {
   my ( $self, $tbl ) = @_;
   die "I need a tbl argument" unless $tbl;
   my @cols = @{$tbl->{mapped}->{columns}};
   return @cols;
}

sub map_values {
   my ( $self, %args ) = @_;
   my @required_args = qw(tbl row);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($tbl, $row) = @args{@required_args};

   die "No values are mapped to $tbl->{db}.$tbl->{tbl}"
      unless $tbl->{mapped};

   my @mapped_columns = @{$tbl->{mapped}->{columns}};
   my @mapped_values  = @{$tbl->{mapped}->{values}};

   my @values;
   for my $i ( 0..$#mapped_columns ) {
      my ($col, $val) = ($mapped_columns[$i], $mapped_values[$i]);
      if ( ref $val ) {
         push @values, $val->(%args);
      }
      else {
         push @values, $row->{$col};
      }
   }
   MKDEBUG && _d('Map values:', @values);
   return \@values;
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
