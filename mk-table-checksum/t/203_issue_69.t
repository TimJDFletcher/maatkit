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
require "$trunk/mk-table-checksum/mk-table-checksum";

my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');
my $slave_dbh  = $sb->get_dbh_for('slave1');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$slave_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave';
}
else {
   plan tests => 2;
}

my $output;
my $cnf='/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-table-checksum/mk-table-checksum -F $cnf 127.0.0.1";

$sb->create_dbs($master_dbh, [qw(test)]);
$sb->load_file('master', 'mk-table-checksum/t/samples/checksum_tbl.sql');
$sb->load_file('master', 'mk-table-checksum/t/samples/issue_21.sql');

# #############################################################################
# Issue 69: mk-table-checksum should be able to re-checksum things that differ
# #############################################################################

`$cmd -d test --replicate test.checksum`;
$slave_dbh->do("update test.checksum set this_crc='' where test.checksum.tbl = 'issue_21'");

# Can't use $cmd; see http://code.google.com/p/maatkit/issues/detail?id=802
`$trunk/mk-table-checksum/mk-table-checksum h=127.1,P=12345,u=msandbox,p=msandbox -d test --replicate test.checksum --replicate-check 1 2>&1`;

$output = `$trunk/mk-table-checksum/mk-table-checksum h=127.1,P=12345,u=msandbox,p=msandbox -d test --replicate test.checksum --replicate-check 1 --recheck | diff $trunk/mk-table-checksum/t/samples/issue_69.txt -`;
ok(!$output, '--recheck reports inconsistent table like --replicate');

# Now check that --recheck actually caused the inconsistent table to be
# re-checksummed on the master.
$output = 'foo';
$output = `$cmd --replicate test.checksum --replicate-check 1`;
ok(!$output, '--recheck re-checksummed inconsistent table; it is now consistent');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
