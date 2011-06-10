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

package ColumnMap;

{ # package scope
use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

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
      my $dsts = $schema->find_column(
         col    => $col,
         ignore => [ $tbl ],  # don't map column to itself
      );
      if ( $dsts ) {
         foreach my $dst ( @$dsts ) {
            MKDEBUG && _d($tbl->{db}, $tbl->{tbl}, $col, 'maps to',
               $dst->{db}, $dst->{tbl}, $col);
            push @mapped_columns, $col;
            push @{$dst->{mapped}->{columns}}, $col;
            push @{$dst->{mapped}->{values}}, '?';
         }
      }
      else {
         MKDEBUG && _d('Column', $col, 'does not map');
      }
   }

   return \@mapped_columns;
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

sub values_mapped_to {
   my ( $self, $tbl ) = @_;
   die "I need a tbl argument" unless $tbl;
   my @vals = @{$tbl->{mapped}->{values}};
   return @vals;
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
