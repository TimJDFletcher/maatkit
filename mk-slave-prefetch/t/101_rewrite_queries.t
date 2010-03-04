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
require "$trunk/mk-slave-prefetch/mk-slave-prefetch";

my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh  = $sb->get_dbh_for('slave1');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave';
}
else {
   plan tests => 2;
}

my $output;
my $cnf  = '/tmp/12346/my.sandbox.cnf';
my $cmd  = "$trunk/mk-slave-prefetch/mk-slave-prefetch -F $cnf --dry-run --print --threads 1 --relay-log";

# MaatkitTest::output() can't capture the STDOUT of the threads.

$output = `$cmd $trunk/mk-slave-prefetch/t/samples/binlog001.txt`;
is(
   $output,
"USE `foo` /*tid1*/
select 1 from  bar where i=2 /*tid1*/
select isnull(coalesce(  i=6 )) from bar where  i=3 /*tid1*/
",
   "Rewritten queries for binlog001.txt"
);

# #############################################################################
# Secondary indexes.
# #############################################################################
$sb->load_file('master', 'mk-slave-prefetch/t/samples/secondary_indexes.sql');
$output = `$cmd $trunk/common/t/samples/binlogs/binlog007.txt --secondary-indexes`;
is(
   $output,
"select 1 from  test2.t where a=1 /*tid1*/
SELECT `c` FROM `test2`.`t` FORCE INDEX(`c`) WHERE `c`=3 LIMIT 1 /*tid1*/
SELECT `b`, `c` FROM `test2`.`t` FORCE INDEX(`b`) WHERE `b`=2 AND `c`=3 LIMIT 1 /*tid1*/
",
   "Get secondary indexes"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
