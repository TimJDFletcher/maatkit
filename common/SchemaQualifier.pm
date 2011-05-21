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

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

sub new {
   my ( $class, %args ) = @_;
   my @required_args = qw(TableParser Quoter);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $self = {
      %args,
      schema                => {},  # db > tbl > col
      duplicate_column_name => {},
      duplicate_table_name  => {},
   };
   return bless $self, $class;
}

sub schema {
   my ( $self ) = @_;
   return $self->{schema};
}

sub get_duplicate_column_names {
   my ( $self ) = @_;
   return keys %{$self->{duplicate_column_name}};
}

sub get_duplicate_table_names {
   my ( $self ) = @_;
   return keys %{$self->{duplicate_table_name}};
}

# Sub: set_schema_from_mysqldump
#   Set internal schema structure using mysqldump output parsed by
#   <MysqldumpParser::parse_create_tables()>.
#
# Parameters:
#   %args - Arguments
#
# Required Arguments:
#   dump - Hashref of parsed mysqldump output from
#          <MysqldumpParser::parse_create_tables()>.
sub set_schema_from_mysqldump {
   my ( $self, %args ) = @_;
   my @required_args = qw(dump);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($dump) = @args{@required_args};

   my $tp = $self->{TableParser};
   my %column_name;
   my %table_name;

   # Clear previous schema, if any.
   $self->{schema} = {};
   my $schema = $self->{schema};

   DATABASE:
   foreach my $db (keys %$dump) {
      if ( !$db ) {
         warn "Empty database from parsed mysqldump output";
         next DATABASE;
      }

      TABLE:
      foreach my $table_def ( @{$dump->{$db}} ) {
         if ( !$table_def ) {
            warn "Empty CREATE TABLE for database $db parsed from mysqldump output";
            next TABLE;
         }
         my $tbl_struct = $tp->parse($table_def);
         $schema->{$db}->{$tbl_struct->{name}} = $tbl_struct->{is_col};

         map { $column_name{$_}++ } @{$tbl_struct->{cols}};
         $table_name{$tbl_struct->{name}}++;
      }
   }

   # Save duplicate column names.
   $self->{duplicate_column_name} = {};
   map { $self->{duplicate_column_name}->{$_} = 1 }
   grep { $column_name{$_} > 1 }
   keys %column_name;

   # Save duplicate table names.
   $self->{duplicate_table_name} = {};
   map { $self->{duplicate_table_name}->{$_} = 1 }
   grep { $table_name{$_} > 1 }
   keys %table_name;

   return;
}

sub qualify_column {
   my ( $self, %args ) = @_;
   my @required_args = qw(column);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($column) = @args{@required_args};

   MKDEBUG && _d('Qualifying', $column);
   my ($col, $tbl, $db) = reverse map { s/`//g; $_ } split /[.]/, $column;
   MKDEBUG && _d('Column', $column, 'has db', $db, 'tbl', $tbl, 'col', $col);

   my %qcol = (
      db  => $db,
      tbl => $tbl,
      col => $col,
   );
   if ( !$qcol{tbl} ) {
      @qcol{qw(db tbl)} = $self->get_table_for_column(column => $qcol{col});
   }
   elsif ( !$qcol{db} ) {
      $qcol{db} = $self->get_database_for_table(table => $qcol{tbl});
   }
   else {
      MKDEBUG && _d('Column is already database-table qualified');
   }

   return \%qcol;
}

sub get_table_for_column {
   my ( $self, %args ) = @_;
   my @required_args = qw(column);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($col) = @args{@required_args};
   MKDEBUG && _d('Getting table for column', $col);

   if ( $self->{duplicate_column_name}->{$col} ) {
      MKDEBUG && _d('Column name is duplicate, cannot qualify it');
      return;
   }

   my $schema = $self->{schema};
   foreach my $db ( keys %{$schema} ) {
      foreach my $tbl ( keys %{$schema->{$db}} ) {
         if ( $schema->{$db}->{$tbl}->{$col} ) {
            MKDEBUG && _d('Column is in database', $db, 'table', $tbl);
            return $db, $tbl;
         }
      }
   }

   MKDEBUG && _d('Failed to find column in any table');
   return;
}

sub get_database_for_table {
   my ( $self, %args ) = @_;
   my @required_args = qw(table);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($tbl) = @args{@required_args};
   MKDEBUG && _d('Getting database for table', $tbl);
   
   if ( $self->{duplicate_table_name}->{$tbl} ) {
      MKDEBUG && _d('Table name is duplicate, cannot qualify it');
      return;
   }

   my $schema = $self->{schema};
   foreach my $db ( keys %{$schema} ) {
     if ( $schema->{$db}->{$tbl} ) {
       MKDEBUG && _d('Table is in database', $db);
       return $db;
     }
   }

   MKDEBUG && _d('Failed to find table in any database');
   return;
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
# End SchemaQualifier package
# ###########################################################################
