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
require "$trunk/mk-table-sync/mk-table-sync";

my $output;
my $vp = new VersionParser();
my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');
my $slave_dbh  = $sb->get_dbh_for('slave1');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$slave_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave';
}
elsif ( !$vp->version_ge($master_dbh, '5.1.5') ) {
      plan skip_all => 'Sandbox master version not >= 5.1';
}
else {
   plan tests => 6;
}

$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
$sb->create_dbs($master_dbh, ['test']);

my @args = qw(-F /tmp/12346/my.sandbox.cnf --sync-to-master P=12346 -t test.t);

# #############################################################################
# Issue 95: Make mk-table-sync force statement-based binlog format on 5.1
# #############################################################################

$master_dbh->do('use test');
$slave_dbh->do('use test');

$master_dbh->do('create table t (i int, unique index (i))');
$master_dbh->do('insert into t values (1),(2)');

$slave_dbh->do('insert into t values (3)');

is_deeply(
   $master_dbh->selectall_arrayref('select * from test.t'),
   [[1],[2]],
   'Data on master before sync'
);

is_deeply(
   $slave_dbh->selectall_arrayref('select * from test.t'),
   [[1],[2],[3]],
   'Data on slave before sync'
);

$master_dbh->do('SET GLOBAL binlog_format="ROW"');
$master_dbh->disconnect();
$master_dbh = $sb->get_dbh_for('master');

is_deeply(
   $master_dbh->selectrow_arrayref('select @@binlog_format'),
   ['ROW'],
   'Set global binlog_format = ROW'
);

is(
   output(
      sub { mk_table_sync::main(@args, qw(--print --execute)) }
   ),
   "DELETE FROM `test`.`t` WHERE `i`=3 LIMIT 1;
",
   "Executed DELETE"
);

sleep 1;
is_deeply(
   $slave_dbh->selectall_arrayref('select * from test.t'),
   [[1],[2]],
   'DELETE replicated to slave'
);

$master_dbh->do('SET GLOBAL binlog_format="STATEMENT"');
$master_dbh->disconnect();
$master_dbh = $sb->get_dbh_for('master');

is_deeply(
   $master_dbh->selectrow_arrayref('select @@binlog_format'),
   ['STATEMENT'],
   'Set global binlog_format = STATEMENT'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
