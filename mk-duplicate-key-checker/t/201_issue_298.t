#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-duplicate-key-checker/mk-duplicate-key-checker";

my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 1;
}

my $output;
my $cnf = "/tmp/12345/my.sandbox.cnf";
my $cmd = "$trunk/mk-duplicate-key-checker/mk-duplicate-key-checker -F $cnf -h 127.1";

$sb->wipe_clean($dbh);

# #############################################################################
# Issue 298: mk-duplicate-key-checker crashes
# #############################################################################
$output = `$cmd -d mysql -t columns_priv 2>&1`;
unlike($output, qr/Use of uninitialized var/, 'Does not crash on undef var');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
