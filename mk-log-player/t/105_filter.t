#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-log-player/mk-log-player";

my $output;
my $tmpdir = '/tmp/mk-log-player';
my $cmd = "$trunk/mk-log-player/mk-log-player --base-dir $tmpdir";

diag(`rm -rf $tmpdir 2>/dev/null; mkdir $tmpdir`);

# #############################################################################
# Issue 571: Add --filter to mk-log-player
# #############################################################################
`$cmd --split Thread_id $trunk/common/t/samples/binlog001.txt --type binlog --session-files 1 --filter '\$event->{arg} && \$event->{arg} eq \"foo\"'`;
ok(
   !-f "$tmpdir/sessions-1.txt",
   '--filter'
);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $tmpdir 2>/dev/null`);
exit;
