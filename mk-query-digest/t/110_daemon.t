#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

use MaatkitTest;
use Sandbox;
use DSNParser;

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

my $output;

# #########################################################################
# Issue 391: Add --pid option to all scripts
# #########################################################################
`touch /tmp/mk-script.pid`;
$output = `$trunk/mk-query-digest/mk-query-digest $trunk/commont/t/samples/slow002.txt --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (--pid without --daemonize) (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# #########################################################################
# Daemonizing and pid creation
# #########################################################################
SKIP: {
   skip "Cannot connect to sandbox master", 5 unless $dbh;

   `$trunk/mk-query-digest/mk-query-digest --daemonize --pid /tmp/mk-query-digest.pid --processlist h=127.1,P=12345,u=msandbox,p=msandbox --log /dev/null`;
   $output = `ps -eaf | grep mk-query-digest | grep daemonize`;
   like($output, qr/$trunk\/mk-query-digest\/mk-query-digest/, 'It is running');
   ok(-f '/tmp/mk-query-digest.pid', 'PID file created');

   my ($pid) = $output =~ /\s+(\d+)\s+/;
   $output = `cat /tmp/mk-query-digest.pid`;
   is($output, $pid, 'PID file has correct PID');

   kill 15, $pid;
   sleep 1;
   $output = `ps -eaf | grep mk-query-digest | grep daemonize`;
   unlike($output, qr/$trunk\/mk-query-digest\/mk-query-digest/, 'It is not running');
   ok(
      !-f '/tmp/mk-query-digest.pid',
      'Removes its PID file'
   );
};

# #############################################################################
# Done.
# #############################################################################
exit;
