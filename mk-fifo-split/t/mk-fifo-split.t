#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

use MaatkitTest;
require "$trunk/mk-fifo-split/mk-fifo-split";

unlink('/tmp/mk-fifo-split');

my $cmd = "$trunk/mk-fifo-split/mk-fifo-split";

my $output = `$cmd --help`;
like($output, qr/Options and values/, 'It lives');

system("($cmd --lines 10000 $trunk/mk-fifo-split/mk-fifo-split > /dev/null 2>&1 < /dev/null)&");
sleep(1);

open my $fh, '<', '/tmp/mk-fifo-split' or die $OS_ERROR;
my $contents = do { local $INPUT_RECORD_SEPARATOR; <$fh>; };
close $fh;

open my $fh2, '<', "$trunk/mk-fifo-split/mk-fifo-split" or die $OS_ERROR;
my $contents2 = do { local $INPUT_RECORD_SEPARATOR; <$fh2>; };
close $fh2;

ok($contents eq $contents2, 'I read the file');

system("($cmd $trunk/mk-fifo-split/t/file_with_lines --offset 2 > /dev/null 2>&1 < /dev/null)&");
sleep(1);

open $fh, '<', '/tmp/mk-fifo-split' or die $OS_ERROR;
$contents = do { local $INPUT_RECORD_SEPARATOR; <$fh>; };
close $fh;

is($contents, <<EOF
     2	hi
     3	there
     4	b
     5	c
     6	d
EOF
, 'Offset works');

# #########################################################################
# Issue 391: Add --pid option to all scripts
# #########################################################################
`touch /tmp/mk-script.pid`;
$output = `$cmd --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# #############################################################################
# Done.
# #############################################################################
exit;
