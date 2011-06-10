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
# SchemaQualifier package $Revision$
# ###########################################################################
package SchemaQualifier;

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
# Optional Arguments:
#   allow_duplicate_columns - Allow duplicate column names (default false)
#   allow_duplicate_tables  - Allow duplicate table names (default false)
#
# Returns:
#  SchemaQualifier object
sub new {
   my ( $class, %args ) = @_;
   my @required_args = qw();
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   my $self = {
      %args,
      schema  => {},  # keyed off db->tbl
      columns => {},
      tables  => {},
   };
   return bless $self, $class;
}

sub is_duplicate_column {
   my ( $self, $col ) = @_;
   return unless $col;
   return ($self->{columns}->{$col} || 0) > 1 ? 1 : 0;
}

sub is_duplicate_table {
   my ( $self, $tbl ) = @_;
   return unless $tbl;
   return ($self->{tables}->{$tbl} || 0) > 1 ? 1 : 0;
}

# Sub: add_schema_object
#   Add a schema object.  This sub is called by
#   <SchemaIterator::next_schema_object()>.
#
# Parameters:
#   $schema_object - Schema object hashref.
#
# Required Arguments:
#   schema_object - Schema object hashref.
sub add_schema_object {
   my ( $self, $schema_object ) = @_;
   die "I need an obj argument" unless $schema_object;

   my ($db, $tbl) = @{$schema_object}{qw(db tbl)};
   my $tbl_struct = $schema_object->{tbl_struct};
   if ( !$tbl_struct ) {
      warn "No table structure for $db.$tbl";
      next SCHEMA_OBJECT;
   }
   $self->{schema}->{$db}->{$tbl} = $tbl_struct->{is_col};

   if ( !$self->{allow_duplicate_columns} ) {
      map { $self->{columns}->{$_}++ } @{$tbl_struct->{cols}};
   }
   if ( !$self->{allow_duplicate_tables} ) {
      $self->{tables}->{$tbl_struct->{name}}++;
   }

   return;
}

sub qualify_column {
   my ( $self, $column ) = @_;
   die "I need a column argument" unless $column;
   MKDEBUG && _d('Qualifying', $column);

   my ($col, $tbl, $db) = reverse map { s/`//g; $_ } split /[.]/, $column;
   MKDEBUG && _d('Column', $column, 'has db', $db, 'tbl', $tbl, 'col', $col);

   my $original_col = {db => $db, tbl => $tbl, col => $col};
   my @qcols;
   if ( !$tbl ) {
      if ( $self->is_duplicate_column($col) ) {
         MKDEBUG && _d('Column name is duplicate, cannot qualify it');
      }
      else {
         foreach my $tbl ( $self->_get_tables_for_column($col) ) {
            push @qcols, {
               db  => $tbl->[0],
               tbl => $tbl->[1],
               col => $col,
            };
         }
         if ( !@qcols ) {
            MKDEBUG && _d('Column', $col, 'does not exist');
         }
      }
   }
   elsif ( !$db ) {
      if ( $self->is_duplicate_table($tbl) ) {
         MKDEBUG && _d('Table name is duplicate, cannot qualify it');
      }
      else {
         foreach my $db ( $self->_get_database_for_table($tbl) ) {
            push @qcols, {
               db  => $db,
               tbl => $tbl,
               col => $col,
            };
         }
         if ( !@qcols ) {
            MKDEBUG && _d('Table', $tbl, 'does not exist');
         }
      }
   }
   else {
      MKDEBUG && _d('Column is already database-table qualified');
   }

   # If @qcols is empty, then we failed to qualify the column.
   # Return the original, whatever was given to us.
   push @qcols, $original_col unless @qcols;

   # If duplicate columns are allowed, then return an arryref.  The caller
   # should expect this since the column may be in more than one table.
   # Else, there should only be one qualified column in @qcols, so return it.
   return $self->{allow_duplicate_columns} ? \@qcols : shift @qcols;
}

sub _get_tables_for_column {
   my ( $self, $col ) = @_;
   die "I need a col argument" unless $col;
   MKDEBUG && _d('Getting tables for column', $col);
   
   my $schema = $self->{schema};
   my @tbls;
   foreach my $db ( keys %{$schema} ) {
      foreach my $tbl ( keys %{$schema->{$db}} ) {
         if ( $schema->{$db}->{$tbl}->{$col} ) {
            MKDEBUG && _d('Column is in database', $db, 'table', $tbl);
            push @tbls, [$db, $tbl];
         }
      }
   }

   return @tbls;
}

sub _get_database_for_table {
   my ( $self, $tbl ) = @_;
   die "I need a tbl argument" unless $tbl;
   MKDEBUG && _d('Getting databases for table', $tbl);
   
   my $schema = $self->{schema};
   my @dbs;
   foreach my $db ( keys %{$schema} ) {
     if ( $schema->{$db}->{$tbl} ) {
       MKDEBUG && _d('Table is in database', $db);
       push @dbs, $db;
     }
   }

   return @dbs;
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
# End SchemaQualifier package
# ###########################################################################
