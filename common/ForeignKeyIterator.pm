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
# ForeignKeyIterator package $Revision$
# ###########################################################################
package ForeignKeyIterator;

{ # package scope
use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use constant MKDEBUG => $ENV{MKDEBUG} || 0;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

# Sub: new
#
# Parameters:
#   %args - Arguments
#
# Required Arguments:
#   db             - Database of tbl.
#   tbl            - Table to iterate from to its referenced tables.
#   SchemaIterator - <SchemaIterator> object.
#   TableParser    - <TableParser> object.
#   Quoter         - <Quoter> object.
#
# Optional Arguments:
#   reverse - Iterate in reverse, from referenced tables to tbl.
#
# Returns:
#   ForeignKeyIterator object
sub new {
   my ( $class, %args ) = @_;
   my @required_args = qw(db tbl SchemaIterator TableParser Quoter);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   MKDEBUG && _d('Reverse iteration:', $args{reverse} ? 'yes' : 'no');
   my $self = {
      %args,
   };

   return bless $self, $class;
}

# Sub: next_schema_object
#   Return the next schema object or undef when no more schema objects.
#
# Returns:
#   Hashref of schema object with at least a db and tbl keys, like
#   (start code)
#   {
#      db   => 'test',
#      tbl  => 'a',
#      ddl  => "CREATE TABLE `a` (
#                 `c1` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
#                 `c2` varchar(45) NOT NULL
#               );",
#      fks  => hasref from <TableParser::get_fks()>,
#   }
#   (end code)
#   The ddl is suitable for <TableParser::parse()>.
sub next_schema_object {
   my ( $self ) = @_;

   if ( !exists $self->{fk_refs} ) {
      $self->_set_fk_refs();
   }

   my $schema_obj;
   my $fk_ref = $self->{reverse} ? shift @{$self->{fk_refs}}
              :                    pop   @{$self->{fk_refs}};
   if ( $fk_ref ) {
      my $fk_ref_schema = $self->{schema}->{$fk_ref->{db}}->{$fk_ref->{tbl}};
      $schema_obj  = {
         db  => $fk_ref->{db},
         tbl => $fk_ref->{tbl},
         ddl => $fk_ref_schema->{ddl},
         fks => $fk_ref_schema->{fks},
      };
   }
   MKDEBUG && _d('Next schema object:', Dumper($schema_obj));
   return $schema_obj;
}

sub _set_fk_refs {
   my ( $self ) = @_;
   $self->_set_schema();

   my @fk_refs = $self->_recurse_fk_references($self->{schema});
   MKDEBUG && _d('Foreign key table order:', Dumper(\@fk_refs));
   $self->{fk_refs} = \@fk_refs;

   return;
}

sub _set_schema {
   my ( $self ) = @_;
   my $schema_itr = $self->{SchemaIterator};
   my $tp         = $self->{TableParser};
   my $q          = $self->{Quoter};
   MKDEBUG && _d('Setting schema from SchemaIterator');

   my %schema;
   SCHEMA_OBJECT:
   while ( my $obj = $schema_itr->next_schema_object() ) {
      my ($db, $tbl) = @{$obj}{qw(db tbl)};

      if ( !$obj->{ddl} ) {
         warn "No CREATE TABLE for $db.$tbl";
         next SCHEMA_OBJECT;
      }
      $schema{$db}->{$tbl}->{ddl} = $obj->{ddl};

      my $fks = $tp->get_fks($obj->{ddl}, { database => $db });
      if ( $fks && scalar values %$fks ) {
         $schema{$db}->{$tbl}->{fks} = $fks;
         foreach my $fk ( values %$fks ) {
            my ($fk_db, $fk_tbl) = $q->split_unquote($fk->{parent_tbl});
            push @{$schema{$db}->{$tbl}->{references}}, [$fk_db, $fk_tbl];
            push @{$schema{$fk_db}->{$fk_tbl}->{referenced_by}}, [$db, $tbl];
         }
      }
   }

   $self->{schema} = \%schema;
   return;
}

sub _recurse_fk_references {
   my ( $self, $schema, $db, $tbl, $seen ) = @_;

   if ( !$db || !$tbl || !$seen ) {
      $db    = $self->{db};
      $tbl   = $self->{tbl};
      $seen  = {};
   }

   if ( $seen && $seen->{"$db$tbl"}++ ) {
      MKDEBUG && _d('Circular reference, already seen', $db, $tbl);
      return;
   }
   MKDEBUG && _d('Recursing from', $db, $tbl);

   my @fk_refs;
   if ( $schema->{$db}->{$tbl}->{references} ) {
      foreach my $refed_obj ( @{$schema->{$db}->{$tbl}->{references}} ) {
         MKDEBUG && _d($db, $tbl, 'references', @$refed_obj);
         push @fk_refs,
            $self->_recurse_fk_references($schema, @$refed_obj, $seen);
      }
   }

   MKDEBUG && _d('No more tables referenced by', $db, $tbl);
   push @fk_refs, { db => $db, tbl => $tbl };

   return @fk_refs;
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
# End ForeignKeyIterator package
# ###########################################################################
