# This program is copyright 2009-@CURRENTYEAR@ Percona Inc.
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
# ExplainAnalyzer package $Revision$
# ###########################################################################
package ExplainAnalyzer;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;
use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(QueryRewriter QueryParser) ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   my $self = {
      %args,
   };
   return bless $self, $class;
}

# Gets an EXPLAIN plan for a query.  The arguments are:
#  dbh   The $dbh, which should already have the correct default database.  This
#        module does not run USE to select a default database.
#  sql   The query text.
# The return value is an arrayref of hash references gotten from EXPLAIN.  If
# the sql is not a SELECT, we try to convert it into one.
sub explain_query {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(dbh sql) ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   my ($sql, $dbh) = @args{qw(sql dbh)};
   if ( $sql !~ m/^\s*select/i ) {
      $sql = $self->{QueryRewriter}->convert_to_select($sql);
   }
   return $dbh->selectall_arrayref("EXPLAIN $sql", { Slice => {} });
}

# Normalizes raw EXPLAIN into a format that's easier to work with.  For example,
# the Extra column is parsed into a hash.  Accepts the output of explain_query()
# as input.
sub normalize {
   my ( $self, $explain ) = @_;
   my @result; # Don't modify the input.

   foreach my $row ( @$explain ) {
      $row = { %$row }; # Make a copy -- don't modify the input.

      # Several of the columns are really arrays of values in many cases.  For
      # example, the "key" column has an array when there is an index merge.
      foreach my $col ( qw(key possible_keys key_len ref) ) {
         $row->{$col} = [ split(/,/, $row->{$col} || '') ];
      }

      # Handle the Extra column.  Parse it into a hash by splitting on
      # semicolons.  There are many special cases to handle.
      $row->{Extra} = {
         map {
            my $var = $_;

            # Index merge query plans have an array of indexes to split up.
            if ( my($key, $vals) = $var =~ m/(Using union)\(([^)]+)\)/ ) {
               $key => [ split(/,/, $vals) ];
            }

            # The default is just "this key/characteristic/flag exists."
            else {
               $var => 1;
            }
         }
         split(/; /, $row->{Extra}) # Split on semicolons.
      };

      push @result, $row;
   }

   return \@result;
}

# Trims down alternate indexes to those that were truly alternates (were not
# actually used).  For example, if key = 'foo' and possible_keys = 'foo,bar',
# then foo isn't an alternate index, only bar is.  The arguments are arrayrefs,
# and the return value is an arrayref too.
sub get_alternate_indexes {
   my ( $self, $keys, $possible_keys ) = @_;
   my %used = map { $_ => 1 } @$keys;
   return [ grep { !$used{$_} } @$possible_keys ];
}

# Returns a data structure that shows which indexes were used and considered for
# a given query and EXPLAIN plan.  Input parameters are:
#  sql      The SQL of the query.
#  db       The default database.  When a table's database is not explicitly
#           qualified in the SQL itself, it defaults to this (optional) value.
#  explain  The normalized EXPLAIN plan: the output from $self->normalize().
# The return value is an arrayref of hashrefs, one per row in the query.  Each
# hashref has the following structure:
#  db    =>    The database of the table in question
#  tbl   =>    The table that was accessed
#  idx   =>    An arrayref of indexes accessed in this table
#  alt   =>    An arrayref of indexes considered but not accessed
sub get_index_usage {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(sql explain) ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   my ($sql, $explain) = @args{qw(sql explain)};
   my @result;

   # First we must get a lookup data structure to translate the possibly aliased
   # names back into real table names.
   my $lookup = $self->{QueryParser}->get_aliases($sql);

   foreach my $row ( @$explain ) {
      my $table = $lookup->{TABLE}->{$row->{table}} || $row->{table};
      my $db    = $lookup->{DATABASE}->{$table}     || $args{db};
      push @result, {
         db  => $db,
         tbl => $table,
         idx => $row->{key},
         alt => $self->get_alternate_indexes(
                  $row->{key}, $row->{possible_keys}),
      };
   }

   return \@result;
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
# End ExplainAnalyzer package
# ###########################################################################
