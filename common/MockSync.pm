# This program is copyright 2007-2010 Baron Schwartz.
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

# A package to mock up a syncer.  Used by RowDiff.t.
package MockSync;

use strict;
use warnings FATAL => 'all';

sub new {
   return bless [], shift;
}

sub same_row {
   my ( $self, $lr, $rr ) = @_;
   push @$self, 'same';
}

sub not_in_right {
   my ( $self, $lr ) = @_;
   push @$self, [ 'not in right', $lr];
}

sub not_in_left {
   my ( $self, $rr ) = @_;
   push @$self, [ 'not in left', $rr];
}

sub done_with_rows {
   my ( $self ) = @_;
   push @$self, 'done';
}

sub key_cols {
   return [qw(a)];
}

1;
