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
# Schema package $Revision$
# ###########################################################################
package Schema;

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
# Returns:
#  Schema object
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

sub get_table {
   my ( $self, $db_name, $tbl_name ) = @_;
   if ( exists $self->{schema}->{$db_name}
        && exists $self->{schema}->{$db_name}->{$tbl_name} ) {
      return $self->{schema}->{$db_name}->{$tbl_name};
   }
   return;
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
sub add_schema_object {
   my ( $self, $schema_object ) = @_;
   die "I need a schema_object argument" unless $schema_object;

   my ($db, $tbl) = @{$schema_object}{qw(db tbl)};
   if ( !$db || !$tbl ) {
      warn "No database or table for schema object";
      return;
   }

   my $tbl_struct = $schema_object->{tbl_struct};
   if ( !$tbl_struct ) {
      warn "No table structure for $db.$tbl";
      return;
   }

   # Add/save this schema object.
   $self->{schema}->{$db}->{$tbl} = $schema_object;

   # Get duplicate column and table names.
   map { $self->{columns}->{$_}++ } @{$tbl_struct->{cols}};
   $self->{tables}->{$tbl_struct->{name}}++;

   return;
}

sub find_column {
   my ( $self, %args ) = @_;
   my $ignore = $args{ignore};
   my $schema = $self->{schema};

   my ($col, $tbl, $db);
   if ( my $col_name = $args{col_name} ) {
      ($col, $tbl, $db) = reverse map { s/`//g; $_ } split /[.]/, $col_name;
      MKDEBUG && _d('Column', $col_name, 'has db', $db, 'tbl', $tbl,
         'col', $col);
   }
   else {
      ($col, $tbl, $db) = @args{qw(col tbl db)};
   }

   if ( !$col ) {
      MKDEBUG && _d('No column specified or parsed');
      return;
   }
   MKDEBUG && _d('Finding column', $col, 'in', $db, $tbl);

   if ( $db && !$schema->{$db} ) {
      MKDEBUG && _d('Database', $db, 'does not exist');
      return;
   }

   if ( $db && $tbl && !$schema->{$db}->{$tbl} ) {
      MKDEBUG && _d('Table', $tbl, 'does not exist in database', $db);
      return;
   }

   my @tbls;
   my @search_dbs = $db ? ($db) : keys %$schema;
   DATABASE:
   foreach my $search_db ( @search_dbs ) {
      my @search_tbls = $tbl ? ($tbl) : keys %{$schema->{$search_db}};

      TABLE:
      foreach my $search_tbl ( @search_tbls ) {
         next DATABASE unless exists $schema->{$search_db}->{$search_tbl};

         if ( $ignore
              && grep { $_->{db} eq $search_db && $_->{tbl} eq $search_tbl }
                 @$ignore ) {
            MKDEBUG && _d('Ignoring', $search_db, $search_tbl, $col);
            next TABLE;
         }

         my $tbl = $schema->{$search_db}->{$search_tbl};
         if ( $tbl->{tbl_struct}->{is_col}->{$col} ) {
            MKDEBUG && _d('Column', $col, 'exists in', $tbl->{db}, $tbl->{tbl});
            push @tbls, $tbl;
         }
      }
   }

   return \@tbls;
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
# End Schema package
# ###########################################################################
