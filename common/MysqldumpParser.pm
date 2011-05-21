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
# MysqldumpParser package $Revision$
# ###########################################################################
package MysqldumpParser;

{ # package scope
use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

my $open_comment = qr{/\*!\d{5} };

sub new {
   my ( $class, %args ) = @_;
   my @required_args = qw();
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $self = {
      %args,
   };
   return bless $self, $class;
}

# Sub: parse_create_tables
#   Parse all CREATE TABLE statements from a file containing
#   mysqldump --no-data output.
#
# Parameters:
#   %args - Arguments
#
# Required Arguments:
#   file - File name to parse.
#
# Returns:
#   Hashref keyed on database with arrayrefs of SHOW CREATE statements.
sub parse_create_tables {
   my ( $self, %args ) = @_;
   my @required_args = qw(file);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($file) = @args{@required_args};

   MKDEBUG && _d('Parsing CREATE TABLE from', $file);
   open my $fh, '<', $file
      or die "Cannot open $file: $OS_ERROR";

   local $INPUT_RECORD_SEPARATOR = '';

   my %schema;
   my $db = '';
   CHUNK:
   while (defined(my $chunk = <$fh>)) {
      MKDEBUG && _d('db:', $db, 'chunk:', $chunk);

      if ($chunk =~ m/Database: (\S+)/) {
         # If the file is a dump of one db, then the only indication of that
         # db is in a comment at the start of the file like,
         #   -- Host: localhost    Database: sakila
         # If the dump is of multiple dbs, then there are both these same
         # comments and USE statements.  We look for the comment which is
         # unique to both single and multi-db dumps.
         $db = $1; # XXX
         $db =~ s/^`//;  # strip leading `
         $db =~ s/`$//;  # and trailing `
         MKDEBUG && _d('New db:', $db);
      }
      elsif ($chunk =~ m/CREATE TABLE/) {
         MKDEBUG && _d('Chunk has CREATE TABLE');

         if ($chunk =~ m/DROP VIEW IF EXISTS/) {
            # Tables that are actually views have this DROP statment in the
            # chunk just before the CREATE TABLE.  We don't want views.
            MKDEBUG && _d('Table is a VIEW, skipping');
            next CHUNK;
         }

         # The open comment is usually present for a view table, which we
         # probably already detected and skipped above, but this is left her
         # just in case mysqldump wraps other CREATE TABLE statements in a
         # a version comment that I don't know about yet.
         my ($create_table)
            = $chunk =~ m/^(?:$open_comment)?(CREATE TABLE.+?;)$/ms;
         if ( !$create_table ) {
            warn "Failed to parse CREATE TABLE from\n" . $chunk;
            next CHUNK;
         }
         $create_table =~ s/ \*\/;\Z/;/;  # remove end of version comment

         push @{$schema{$db}}, $create_table;
      }
   }

   close $fh;

   return \%schema;
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
# End MysqldumpParser package
# ###########################################################################
