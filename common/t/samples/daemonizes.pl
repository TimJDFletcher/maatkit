#!/usr/bin/env perl

# This script is used by Daemon.t because that test script
# cannot daemonize itself.

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use constant MKDEBUG => $ENV{MKDEBUG};

use Daemon;
use OptionParser;
use MaatkitTest;

my $o = new OptionParser(
   strict      => 0,
   description => 'daemonizes, prints to STDOUT and STDERR, sleeps and exits.',
   prompt      => 'SLEEP_TIME [ARGS]',
);
$o->get_specs("$trunk/common/t/samples/daemonizes.pl");
$o->get_opts();

if ( scalar @ARGV < 1 ) {
   $o->save_error('No SLEEP_TIME specified');
}

$o->usage_or_errors();

my $daemon;
if ( $o->get('daemonize') ) {
   $daemon = new Daemon(o=>$o);
   $daemon->daemonize();

   print "STDOUT\n";
   print STDERR "STDERR\n";

   sleep $ARGV[0];
}

exit;

# ############################################################################
# Documentation.
# ############################################################################

=pod

=head1 OPTIONS

=over

=item --daemonize

Fork to background and detach (POSIX only).  This probably doesn't work on
Microsoft Windows.

=item --help

Show help and exit.

=item --log

type: string

Print all output to this file when daemonized.

=item --pid

type: string 

Create the given PID file when daemonized.

=back
