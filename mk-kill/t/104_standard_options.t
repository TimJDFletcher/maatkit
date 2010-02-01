#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 5;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-kill/mk-kill";

my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');

my $output;
my $cnf='/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-kill/mk-kill -F $cnf -h 127.1";

# #########################################################################
# Check that it daemonizes.
# #########################################################################

SKIP: {
   skip 'Cannot connect to sandbox master', 4 unless $master_dbh;

   # There's no hung queries so we'll just make sure it outputs anything,
   # its debug stuff in this case.
   `$cmd --print --interval 1s --iterations 2 --pid /tmp/mk-kill.pid --log /tmp/mk-kill.log --daemonize`;
   $output = `ps -eaf | grep 'mk-kill \-F'`;
   like(
      $output,
      qr/mk-kill -F /,
      'It lives daemonized'
   );
   ok(
      -f '/tmp/mk-kill.pid',
      'PID file created'
   );
   ok(
      -f '/tmp/mk-kill.log',
      'Log file created'
   );

   sleep 2;
   ok(
      !-f '/tmp/mk-kill.pid',
      'PID file removed'
   );

   diag(`rm -rf /tmp/mk-kill.log`);
}

# #########################################################################
# Issue 391: Add --pid option to all scripts
# #########################################################################
`touch /tmp/mk-script.pid`;
$output = `$cmd $trunk/common/t/samples/pl/recset006.txt --match-state Locked  --print --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (--pid without --daemonize) (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh) if $master_dbh;
exit;
