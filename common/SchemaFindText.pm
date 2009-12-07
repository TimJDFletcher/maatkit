# This program is copyright 2008-2009 Baron Schwartz.
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
# SchemaFindText package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package SchemaFindText;

use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# Arguments:
# * fh => filehandle
sub new {
   my ( $class, %args ) = @_;
   bless {
      %args,
      last_tbl_ddl => undef,
      queued_db    => undef,
   }, $class;
}

sub next_db {
   my ( $self ) = @_;
   if ( $self->{queued_db} ) {
      my $db = $self->{queued_db};
      $self->{queued_db} = undef;
      return $db;
   }
   local $RS = "";
   my $fh = $self->{fh};
   while ( defined (my $text = <$fh>) ) {
      my ($db) = $text =~ m/^USE `([^`]+)`/;
      return $db if $db;
   }
}

sub next_tbl {
   my ( $self ) = @_;
   local $RS = "";
   my $fh = $self->{fh};
   while ( defined (my $text = <$fh>) ) {
      if ( my ($db) = $text =~ m/^USE `([^`]+)`/ ) {
         $self->{queued_db} = $db;
         return undef;
      }
      my ($ddl) = $text =~ m/^(CREATE TABLE.*?^\)[^\n]*);\n/sm;
      if ( $ddl ) {
         $self->{last_tbl_ddl} = $ddl;
         my ( $tbl ) = $ddl =~ m/CREATE TABLE `([^`]+)`/;
         return $tbl;
      }
   }
}

sub last_tbl_ddl {
   my ( $self ) = @_;
   return $self->{last_tbl_ddl};
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
# End SchemaFindText package
# ###########################################################################
