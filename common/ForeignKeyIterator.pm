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
# Returns:
#   ForeignKeyIterator object
sub new {
   my ( $class, %args ) = @_;
   my @required_args = qw(db tbl SchemaIterator TableParser Quoter);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   my $self = {
      %args,
   };

   return bless $self, $class;
}

# Sub: next_schema_object
#   Return the next schema object or undef when no more schema objects.
#
# Returns:
#   Hash of schema object with at least a db and tbl keys, like
#   (start code)
#   (
#      db   => 'test',
#      tbl  => 'a',
#      ddl  => "CREATE TABLE `a` (
#                 `c1` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
#                 `c2` varchar(45) NOT NULL
#               );",
#   )
#   (end code)
#   The ddl is suitable for <TableParser::parse()>.
sub next_schema_object {
   my ( $self ) = @_;

   if ( !$self->{schema_objs} ) {
      $self->_walk_foreign_keys();
   }

   #my %schema_object = shift @{$self->{schema_objs}};
   #MKDEBUG && _d('Next schema object:', Dumper(\%schema_object));
   #return %schema_object;
}

sub _walk_foreign_keys {
   my ( $self ) = @_;

   my $schema    = $self->_get_schema();
   my @fk_struct = $self->_recurse_schema($schema);
   print Dumper(\@fk_struct);

   return;
}

sub _get_schema {
   my ( $self ) = @_;
   my $schema_itr = $self->{SchemaIterator};
   my $tp         = $self->{TableParser};
   my $q          = $self->{Quoter};

   my %schema;
   SCHEMA_OBJECT:
   while ( my %obj = $schema_itr->next_schema_object() ) {
      if ( !$obj{ddl} ) {
         warn "No CREATE TABLE for $obj{db}.$obj{tbl}";
         next SCHEMA_OBJECT;
      }
      my $this_obj_refs = $schema{$obj{db}}->{$obj{tbl}}->{references} = [];
      my $fks           = $tp->get_fks($obj{ddl}, { database => $obj{db} });
      foreach my $fk ( values %$fks ) {
         my ($db, $tbl) = $q->split_unquote($fk->{parent_tbl});
         push @{$this_obj_refs}, [$db, $tbl];
         push @{$schema{$db}->{$tbl}->{referenced_by}}, [$obj{db}, $obj{tbl}];
      }
   }

   return \%schema;
}

sub _recurse_schema {
   my ( $self, $schema, $db, $tbl, $seen, $refno ) = @_;

   if ( !$db || !$tbl || !$seen ) {
      $db    = $self->{db};
      $tbl   = $self->{tbl};
      $seen  = {};
      $refno = 1;  # for debugging
   }

   if ( $seen && $seen->{"$db$tbl"}++ ) {
      MKDEBUG && _d('Circular reference, already seen', $db, $tbl);
      return;
   }
   MKDEBUG && _d($refno, 'Recursing from', $db, $tbl);

   my @schema_objs;
   if ( scalar @{$schema->{$db}->{$tbl}->{references}} ) {
      foreach my $refed_obj ( @{$schema->{$db}->{$tbl}->{references}} ) {
         MKDEBUG && _d($db, $tbl, 'references', @$refed_obj);
         push @schema_objs, $self->_recurse_schema($schema, @$refed_obj, $seen, $refno++);
      }
   }

   MKDEBUG && _d('No more tables referenced by', $db, $tbl);
   push @schema_objs, [$db, $tbl];
   return @schema_objs;
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
