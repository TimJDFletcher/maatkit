# This program is copyright 2007-2009 Baron Schwartz.
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
# ChangeHandler package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package ChangeHandler;

use English qw(-no_match_vars);

my $DUPE_KEY  = qr/Duplicate entry/;
our @ACTIONS  = qw(DELETE REPLACE INSERT UPDATE);

use constant MKDEBUG => $ENV{MKDEBUG};

# Arguments:
# * Quoter     Quoter object
# * src_db     Source database
# * src_tbl    Source table
# * dst_db     Destination database
# * dst_tbl    Destination table
# * actions    arrayref of subroutines to call when handling a change.
# * replace    Do UPDATE/INSERT as REPLACE.
# * queue      Queue changes until process_changes is called with a greater
#              queue level.
sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(Quoter dst_db dst_tbl src_db src_tbl replace queue) ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   my $self = { %args, map { $_ => [] } @ACTIONS };
   $self->{dst_db_tbl} = $self->{Quoter}->quote(@args{qw(dst_db dst_tbl)});
   $self->{src_db_tbl} = $self->{Quoter}->quote(@args{qw(src_db src_tbl)});
   $self->{changes} = { map { $_ => 0 } @ACTIONS };
   return bless $self, $class;
}

# If I'm supposed to fetch-back, that means I have to get the full row from the
# database.  For example, someone might call me like so:
# $me->change('UPDATE', { a => 1 })
# but 'a' is only the primary key. I now need to select that row and make an
# UPDATE statement with all of its columns.  The argument is the DB handle used
# to fetch.
sub fetch_back {
   my ( $self, $dbh ) = @_;
   $self->{fetch_back} = $dbh;
   MKDEBUG && _d('Will fetch rows from source when updating destination');
}

sub take_action {
   my ( $self, @sql ) = @_;
   MKDEBUG && _d('Calling subroutines on', @sql);
   foreach my $action ( @{$self->{actions}} ) {
      $action->(@sql);
   }
}

# Arguments: string, hashref, arrayref
sub change {
   my ( $self, $action, $row, $cols ) = @_;
   MKDEBUG && _d($action, 'where', $self->make_where_clause($row, $cols));
   $self->{changes}->{
      $self->{replace} && $action ne 'DELETE' ? 'REPLACE' : $action
   }++;
   if ( $self->{queue} ) {
      $self->__queue($action, $row, $cols);
   }
   else {
      eval {
         my $func = "make_$action";
         $self->take_action($self->$func($row, $cols));
      };
      if ( $EVAL_ERROR =~ m/$DUPE_KEY/ ) {
         MKDEBUG && _d('Duplicate key violation; will queue and rewrite');
         $self->{queue}++;
         $self->{replace} = 1;
         $self->__queue($action, $row, $cols);
      }
      elsif ( $EVAL_ERROR ) {
         die $EVAL_ERROR;
      }
   }
}

sub __queue {
   my ( $self, $action, $row, $cols ) = @_;
   MKDEBUG && _d('Queueing change for later');
   if ( $self->{replace} ) {
      $action = $action eq 'DELETE' ? $action : 'REPLACE';
   }
   push @{$self->{$action}}, [ $row, $cols ];
}

# If called with 1, will process rows that have been deferred from instant
# processing.  If no arg, will process all rows.
sub process_rows {
   my ( $self, $queue_level ) = @_;
   my $error_count = 0;
   TRY: {
      if ( $queue_level && $queue_level < $self->{queue} ) { # see redo below!
         MKDEBUG && _d('Not processing now', $queue_level, '<', $self->{queue});
         return;
      }
      MKDEBUG && _d('Processing rows:');
      my ($row, $cur_act);
      eval {
         foreach my $action ( @ACTIONS ) {
            my $func = "make_$action";
            my $rows = $self->{$action};
            MKDEBUG && _d(scalar(@$rows), 'to', $action);
            $cur_act = $action;
            while ( @$rows ) {
               $row = shift @$rows;
               $self->take_action($self->$func(@$row));
            }
         }
         $error_count = 0;
      };
      if ( !$error_count++ && $EVAL_ERROR =~ m/$DUPE_KEY/ ) {
         MKDEBUG
            && _d('Duplicate key violation; re-queueing and rewriting');
         $self->{queue}++; # Defer rows to the very end
         $self->{replace} = 1;
         $self->__queue($cur_act, @$row);
         redo TRY;
      }
      elsif ( $EVAL_ERROR ) {
         die $EVAL_ERROR;
      }
   }
}

# DELETE never needs to be fetched back.
sub make_DELETE {
   my ( $self, $row, $cols ) = @_;
   MKDEBUG && _d('Make DELETE');
   return "DELETE FROM $self->{dst_db_tbl} WHERE "
      . $self->make_where_clause($row, $cols)
      . ' LIMIT 1';
}

sub make_UPDATE {
   my ( $self, $row, $cols ) = @_;
   MKDEBUG && _d('Make UPDATE');
   if ( $self->{replace} ) {
      return $self->make_row('REPLACE', $row, $cols);
   }
   my %in_where = map { $_ => 1 } @$cols;
   my $where = $self->make_where_clause($row, $cols);
   if ( my $dbh = $self->{fetch_back} ) {
      my $sql = "SELECT * FROM $self->{src_db_tbl} WHERE $where LIMIT 1";
      MKDEBUG && _d('Fetching data for UPDATE:', $sql);
      my $res = $dbh->selectrow_hashref($sql);
      @{$row}{keys %$res} = values %$res;
      $cols = [sort keys %$res];
   }
   else {
      $cols = [ sort keys %$row ];
   }
   return "UPDATE $self->{dst_db_tbl} SET "
      . join(', ', map {
            $self->{Quoter}->quote($_)
            . '=' .  $self->{Quoter}->quote_val($row->{$_})
         } grep { !$in_where{$_} } @$cols)
      . " WHERE $where LIMIT 1";
}

sub make_INSERT {
   my ( $self, $row, $cols ) = @_;
   MKDEBUG && _d('Make INSERT');
   if ( $self->{replace} ) {
      return $self->make_row('REPLACE', $row, $cols);
   }
   return $self->make_row('INSERT', $row, $cols);
}

sub make_REPLACE {
   my ( $self, $row, $cols ) = @_;
   MKDEBUG && _d('Make REPLACE');
   return $self->make_row('REPLACE', $row, $cols);
}

sub make_row {
   my ( $self, $verb, $row, $cols ) = @_;
   my @cols = sort keys %$row;
   if ( my $dbh = $self->{fetch_back} ) {
      my $where = $self->make_where_clause($row, $cols);
      my $sql = "SELECT * FROM $self->{src_db_tbl} WHERE $where LIMIT 1";
      MKDEBUG && _d('Fetching data for UPDATE:', $sql);
      my $res = $dbh->selectrow_hashref($sql);
      @{$row}{keys %$res} = values %$res;
      @cols = sort keys %$res;
   }
   return "$verb INTO $self->{dst_db_tbl}("
      . join(', ', map { $self->{Quoter}->quote($_) } @cols)
      . ') VALUES ('
      . $self->{Quoter}->quote_val( @{$row}{@cols} )
      . ')';
}

sub make_where_clause {
   my ( $self, $row, $cols ) = @_;
   my @clauses = map {
      my $val = $row->{$_};
      my $sep = defined $val ? '=' : ' IS ';
      $self->{Quoter}->quote($_) . $sep . $self->{Quoter}->quote_val($val);
   } @$cols;
   return join(' AND ', @clauses);
}

sub get_changes {
   my ( $self ) = @_;
   return %{$self->{changes}};
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
# End ChangeHandler package
# ###########################################################################
