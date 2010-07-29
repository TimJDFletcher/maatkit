#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-table-checksum/mk-table-checksum";

my $vp  = new VersionParser();
my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 6;
}

my $output = "";
my $cnf    ='/tmp/12345/my.sandbox.cnf';
my @args   = ('-F', $cnf, 'h=127.1', qw(-t hex.t --explain --chunk-size 3));

$sb->load_file('master', "common/t/samples/hex-chunking.sql");

$output = output(
   sub { mk_table_checksum::main(@args) }
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
