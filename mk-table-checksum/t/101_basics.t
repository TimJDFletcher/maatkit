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

my $vp = new VersionParser();
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
   plan tests => 11;
}

my $cnf='/tmp/12345/my.sandbox.cnf';
my ($output, $output2);
my $cmd = "$trunk/mk-table-checksum/mk-table-checksum -F $cnf -d test -t checksum_test 127.0.0.1";

$sb->create_dbs($master_dbh, [qw(test)]);
$sb->load_file('master', 'mk-table-checksum/t/samples/before.sql');

# Test basic functionality with defaults
$output = `$cmd 2>&1`;
like($output, qr/^DATABASE/m, 'The header row is there');
like($output, qr/checksum_test/, 'The results row is there');

my ( $cnt, $crc ) = $output =~ m/checksum_test *\d+ \S+ \S+ *(\d+|NULL) *(\w+)/;
like ( $cnt, qr/1|NULL/, 'One row in the table, or no count' );
if ( $output =~ m/cannot be used; using MD5/ ) {
   # same as md5(md5(1))
   is ( $crc, '28c8edde3d61a0411511d3b1866f0636', 'MD5 is okay' );
}
elsif ( $crc =~ m/^\d+$/ ) {
   is ( $crc, 3036305396, 'CHECKSUM is okay');
}
else {
   # same as sha1(sha1(1))
   is ( $crc, '9c1c01dc3ac1445a500251fc34a15d3e75a849df', 'SHA1 is okay' );
}

# Test that it works with locking
$output = `$cmd --lock --slave-lag --function sha1 --checksum --algorithm ACCUM 2>&1`;
like($output, qr/9c1c01dc3ac1445a500251fc34a15d3e75a849df/, 'Locks' );

SKIP: {
   skip 'MySQL version < 4.1', 5
      unless $vp->version_ge($master_dbh, '4.1.0');

   $output = `$cmd --function CRC32 --checksum --algorithm ACCUM 2>&1`;
   like($output, qr/00000001E9F5DC8E/, 'CRC32 ACCUM' );

   $output = `$cmd --function sha1 --checksum --algorithm ACCUM 2>&1`;
   like($output, qr/9c1c01dc3ac1445a500251fc34a15d3e75a849df/, 'SHA1 ACCUM' );

   # same as sha1(1)
   $output = `$cmd --function sha1 --checksum --algorithm BIT_XOR 2>&1`;
   like($output, qr/356a192b7913b04c54574d18c28d46e6395428ab/, 'SHA1 BIT_XOR' );

   # test that I get the same result with --no-optxor
   $output2 = `$cmd --function sha1 --no-optimize-xor --checksum --algorithm BIT_XOR 2>&1`;
   is($output, $output2, 'Same result with --no-optxor');

   # same as sha1(1)
   $output = `$cmd --checksum --function MD5 --algorithm BIT_XOR 2>&1`;
   like($output, qr/c4ca4238a0b923820dcc509a6f75849b/, 'MD5 BIT_XOR' );
};

$output = `$cmd --checksum --function MD5 --algorithm ACCUM 2>&1`;
like($output, qr/28c8edde3d61a0411511d3b1866f0636/, 'MD5 ACCUM' );

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
