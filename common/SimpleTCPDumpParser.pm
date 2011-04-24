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
# ###########################################################################
# SimpleTCPDumpParser package $Revision$
# ###########################################################################
package SimpleTCPDumpParser;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Time::Local qw(timelocal);
use Data::Dumper;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# Required arguments: watch
sub new {
   my ( $class, %args ) = @_;
   my ($ip, $port) = split(/:/, $args{watch});
   my $self = {
      sessions => {},
      requests => 0,
      port     => $port || 3306,
   };
   return bless $self, $class;
}

# This method accepts an open filehandle and callback functions.  It reads
# events from the filehandle and calls the callbacks with each event.  $misc is
# some placeholder for the future and for compatibility with other query
# sources.
#
# The input is TCP requests and responses, such as the following:
#
# 2011-04-04 18:57:43.804195 IP 10.10.18.253.58297 > 10.10.18.40.3306: tcp 132
# 2011-04-04 18:57:43.804465 IP 10.10.18.40.3306 > 10.10.18.253.58297: tcp 2920
#
# Each event is a hashref of attribute => value pairs such as the following:
#
#  my $event = {
#     id   => '0',                  # Sequentially assigned ID, in arrival order
#     ts   => '1301957863.804195',  # Start timestamp
#     end  => '1301957863.804465',  # End timestamp
#     arg  => undef,                # For compatibility with other modules
#     host => '10.10.18.253',       # Host IP address where the event came from
#     port => '58297',              # TCP port where the event came from
#     ...                           # Other attributes
#  };
#
# Returns the number of events it finds.
sub parse_event {
   my ( $self, %args ) = @_;
   my @required_args = qw(next_event tell);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($next_event, $tell) = @args{@required_args};

   my $sessions   = $self->{sessions};
   my $pos_in_log = $tell->();
   my $line;

   EVENT:
   while ( defined($line = $next_event->()) ) {
      # Split the line into timestamp, source, and destination
      my ( $ts, $us, $src, $dst )
         = $line =~ m/([0-9-]{10} [0-9:]{8})(\.\d{6}) IP (\S+) > (\S+):/;
      next unless $ts;
      my $unix_timestamp = make_ts($ts) . $us;

      # If it's an inbound packet, we record this as the beginning of a request.
      if ( $dst =~ m/\.$self->{port}$/o ) {
         $sessions->{$src} = {
            pos_in_log => $pos_in_log,
            ts         => $unix_timestamp,
            id         => $self->{requests}++,
         };
      }

      # If it's a reply to an inbound request, then we emit an event
      # representing the entire request, and forget that we saw the request.
      elsif (defined (my $event = $sessions->{$dst}) ) {
         my ( $src_host, $src_port ) = $dst =~ m/^(.*)\.(\d+)$/;
         $event->{end}  = $unix_timestamp;
         $event->{host} = $src_host;
         $event->{port} = $src_port;
         $event->{arg}  = undef;
         MKDEBUG && _d('Properties of event:', Dumper($event));
         delete $sessions->{$dst};
         return $event;
      }
      $pos_in_log = $tell->();
   } # EVENT

   $args{oktorun}->(0) if $args{oktorun};
   return;
}

# Function to memo-ize and cache repeated calls to timelocal.  Accepts a string,
# outputs an integer.
{
   my ($last, $result);
   # $time = timelocal($sec,$min,$hour,$mday,$mon,$year);
   sub make_ts {
      my ($arg) = @_;
      if ( !$last || $last ne $arg ) {
         my ($year, $mon, $mday, $hour, $min, $sec) = split(/\D/, $arg);
         $result = timelocal($sec, $min, $hour, $mday, $mon - 1, $year);
         $last   = $arg;
      }
      return $result;
   }
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
# End SimpleTCPDumpParser package
# ###########################################################################
