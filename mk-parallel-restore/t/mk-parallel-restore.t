#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 31;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "perl ../mk-parallel-restore -F $cnf ";
my $mysql = $sb->_use_for('master');

$sb->create_dbs($dbh, ['test']);
`rm -rf /tmp/default`;

my $output = `$cmd mk_parallel_restore_foo --dry-run`;
like(
   $output,
   qr/CREATE TABLE bar\(a int\)/,
   'Found the file',
);
like(
   $output,
   qr{1 tables,\s+1 files,\s+1 successes},
   'Counted the work to be done',
);

$output = `$cmd --ignore-tables bar mk_parallel_restore_foo --dry-run`;
unlike( $output, qr/bar/, '--ignore-tables filtered out bar');

$output = `$cmd --ignore-tables mk_parallel_restore_foo.bar mk_parallel_restore_foo --dry-run`;
unlike( $output, qr/bar/, '--ignore-tables filtered out bar again');

# Actually load the file, and make sure it succeeds.
`$mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_foo'`;
`$mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_bar'`;
$output = `$cmd --create-databases mk_parallel_restore_foo`;
$output = `$mysql -N -e 'select count(*) from mk_parallel_restore_foo.bar'`;
is($output + 0, 0, 'Loaded mk_parallel_restore_foo.bar');

# Test that the --database parameter doesn't specify the database to use for the
# connection, and that --create-databases creates the database for it (bug #1870415).
`$mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_foo'`;
`$mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_bar'`;
$output = `$cmd --database mk_parallel_restore_bar --create-databases mk_parallel_restore_foo`;
$output = `$mysql -N -e 'select count(*) from mk_parallel_restore_bar.bar'`;
is($output + 0, 0, 'Loaded mk_parallel_restore_bar.bar');

# Test that the --defaults-file parameter works (bug #1886866).
# This is implicit in that $cmd specifies --defaults-file
$output = `$cmd --create-databases mk_parallel_restore_foo`;
like($output, qr/1 files,     1 successes,  0 failures/, 'restored');
$output = `$mysql -N -e 'select count(*) from mk_parallel_restore_bar.bar'`;
is($output + 0, 0, 'Loaded mk_parallel_restore_bar.bar');


SKIP: {
   skip 'Sandbox master does not have the sakila database', 5
      unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   $output = `perl ../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir /tmp -d sakila -t film,film_actor,payment,rental`;
   like($output, qr/0 failures/, 'Dumped sakila tables');

   $output = `MKDEBUG=1 $cmd -D test /tmp/default/ 2>&1 | grep -A 6 ' got ' | grep 'Z => ' | awk '{print \$4}' | cut -f1 -d',' | sort --numeric-sort --check --reverse 2>&1`;
   unlike($output, qr/disorder/, 'Tables restored biggest-first by default');   

   `$mysql -e 'DROP TABLE test.film_actor, test.film, test.payment, test.rental'`;

   # Do it all again with > 1 arg in order to test that it does NOT
   # sort by biggest-first, as explained by Baron in issue 31 comment 1.
   $output = `MKDEBUG=1 $cmd -D test /tmp/default/sakila/payment.000000.sql.gz /tmp/default/sakila/film.000000.sql.gz /tmp/default/sakila/rental.000000.sql.gz /tmp/default/sakila/film_actor.000000.sql.gz 2>&1 | grep -A 6 ' got ' | grep 'N => ' | awk '{print \$4}' | cut -f1 -d',' 2>&1`;
   like($output, qr/'payment'\n'film'\n'rental'\n'film_actor'/, 'Tables restored in given order');

   `$mysql -e 'DROP TABLE test.film_actor, test.film, test.payment, test.rental'`;

   # And yet again, but this time test that a given order of tables is
   # ignored if --biggest-first is explicitly given
   $output = `MKDEBUG=1 $cmd -D test --biggest-first /tmp/default/sakila/payment.000000.sql.gz /tmp/default/sakila/film.000000.sql.gz /tmp/default/sakila/rental.000000.sql.gz /tmp/default/sakila/film_actor.000000.sql.gz 2>&1 | grep -A 6 ' got ' |  grep 'Z => ' | awk '{print \$4}' | cut -f1 -d',' | sort --numeric-sort --check --reverse 2>&1`;
   unlike($output, qr/disorder/, 'Explicit --biggest-first overrides given table order');

   `$mysql -e 'DROP TABLE test.film_actor, test.film, test.payment, test.rental'`;

   # And again, because I've yet to better optimize these tests...
   # This time we're just making sure reporting progress by bytes.
   # This is kind of a contrived test, but it's better than nothing.
   $output = `../mk-parallel-restore -F $cnf --progress --dry-run /tmp/default/`;
   like($output, qr/done: [\d\.]+[Mk]\/[\d\.]+[Mk]/, 'Reporting progress by bytes');
};

# #############################################################################
# Issue 30: Add resume functionality to mk-parallel-restore
# #############################################################################
$sb->load_file('master', 'samples/issue_30.sql');
`rm -rf /tmp/default`;
`../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir /tmp -d test -t issue_30 --chunk-size 25`;
# The above makes the following chunks:
#
# #   WHERE                         SIZE  FILE
# --------------------------------------------------------------
# 0:  `id` < 254                    790   issue_30.000000.sql.gz
# 1:  `id` >= 254 AND `id` < 502    619   issue_30.000001.sql.gz
# 2:  `id` >= 502 AND `id` < 750    661   issue_30.000002.sql.gz
# 3:  `id` >= 750                   601   issue_30.000003.sql.gz


# Now we fake like a resume operation died on an edge case:
# after restoring the first row of chunk 2. We should resume
# from chunk 1 to be sure that all of 2 is restored.
my $done_size = (-s '/tmp/default/test/issue_30.000000.sql.gz')
              + (-s '/tmp/default/test/issue_30.000001.sql.gz');
`$mysql -D test -e 'DELETE FROM issue_30 WHERE id > 502'`;
$output = `MKDEBUG=1 $cmd --no-atomic-resume -D test /tmp/default/test/ 2>&1 | grep 'Resuming'`;
like(
   $output,
   qr/Resuming restore of `test`.`issue_30` from chunk 2 with $done_size bytes/,
   'Reports non-atomic resume from chunk 2 (issue 30)'
);

$output = 'foo';
$output = `$mysql -e 'SELECT * FROM test.issue_30' | diff samples/issue_30_all_rows.txt -`;
ok(
   !$output,
   'Resume restored all 100 rows exactly (issue 30)'
);

# Now re-do the operation with atomic-resume.  Since chunk 2 has a row,
# id = 502, it will be considered fully restored and the resume will start
# from chunk 3.  Chunk 2 will be left in a partial state.  This is why
# atomic-resume should not be used with non-transactionally-safe tables.
$done_size += (-s '/tmp/default/test/issue_30.000002.sql.gz');
`$mysql -D test -e 'DELETE FROM issue_30 WHERE id > 502'`;
$output = `MKDEBUG=1 $cmd -D test /tmp/default/test/ 2>&1 | grep 'Resuming'`;
like(
   $output,
   qr/Resuming restore of `test`.`issue_30` from chunk 3 with $done_size bytes/,
   'Reports atomic resume from chunk 3 (issue 30)'
);

$output = 'foo';
$output = `$mysql -e 'SELECT * FROM test.issue_30' | diff samples/issue_30_partial_chunk_2.txt -`;
ok(
   !$output,
   'Resume restored atomic chunks (issue 30)'
);

`rm -rf /tmp/default`;

# Test that resume doesn't do anything on a tab dump because there's
# no chunks file
`../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir /tmp -d test -t issue_30 --tab`;
$output = `MKDEBUG=1 $cmd --no-atomic-resume -D test --local --tab /tmp/default/test/ 2>&1`;
like($output, qr/Cannot resume restore: no chunks file/, 'Does not resume --tab dump (issue 30)');

`rm -rf /tmp/default/`;

# Test that resume doesn't do anything on non-chunked dump because
# there's only 1 chunk: where 1=1
`../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir /tmp -d test -t issue_30 --chunk-size 10000`;
$output = `MKDEBUG=1 $cmd --no-atomic-resume -D test /tmp/default/test/ 2>&1`;
like(
   $output,
   qr/Cannot resume restore: only 1 chunk \(1=1\)/,
   'Does not resume single chunk where 1=1 (issue 30)'
);

`rm -rf /tmp/default`;

# #############################################################################
# Issue 221: mk-parallel-restore resume functionality broken
# #############################################################################

# Test that resume does not die if the table isn't present.
`../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir /tmp -d test -t issue_30 --chunk-size 25`;
`$mysql -D test -e 'DROP TABLE issue_30'`;
$output = `MKDEBUG=1 $cmd -D test /tmp/default/test/ 2>&1 | grep Restoring`;
like($output, qr/Restoring from chunk 0 because table `test`.`issue_30` does not exist/, 'Resume does not die when table is not present (issue 221)');

`rm -rf /tmp/default`;

# #############################################################################
# Issue 57: mk-parallel-restore with --tab doesn't fully replicate 
# #############################################################################

# This test relies on the issue_30 table created somewhere above.

my $slave_dbh = $sb->get_dbh_for('slave1');
SKIP: {
   skip 'Cannot connect to sandbox slave', 2 unless $slave_dbh;

   `../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir /tmp -d test -t issue_30 --tab`;

   # By default a --tab restore should not replicate.
   diag(`/tmp/12345/use -e 'DROP TABLE IF EXISTS test.issue_30'`);
   $slave_dbh->do('USE test');
   my $res = $slave_dbh->selectall_arrayref('SHOW TABLES LIKE "issue_30"');
   ok(!scalar @$res, 'Slave does not have table before --tab restore');

   $res = $dbh->selectall_arrayref('SHOW MASTER STATUS');
   my $master_pos = $res->[0]->[1];

   `$cmd --tab --replace --local --database test /tmp/default/`;
   sleep 1;

   $slave_dbh->do('USE test');
   $res = $slave_dbh->selectall_arrayref('SHOW TABLES LIKE "issue_30"');
   ok(!scalar @$res, 'Slave does not have table after --tab restore');

   $res = $dbh->selectall_arrayref('SHOW MASTER STATUS');
   is($master_pos, $res->[0]->[1], 'Bin log pos unchanged');

   # Test that a --tab --bin-log overrides default behavoir
   # and replicates the restore.
   diag(`/tmp/12345/use -e 'SET SQL_LOG_BIN=0; DROP TABLE IF EXISTS test.issue_30'`);
   `$cmd --bin-log --tab --replace --local --database test /tmp/default/`;
   sleep 1;

   $slave_dbh->do('USE test');
   $res = $slave_dbh->selectall_arrayref('SELECT * FROM test.issue_30');
   is(scalar @$res, 66, '--tab with --bin-log allows replication');


   # Check that non-tab restores do replicate by default.
   `rm -rf /tmp/default/`;
   `../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir /tmp -d test -t issue_30 --chunk-size 25`;

   diag(`/tmp/12345/use -e 'DROP TABLE IF EXISTS test.issue_30'`);
   `$cmd /tmp/default`;
   sleep 1;

   $slave_dbh->do('USE test');
   $res = $slave_dbh->selectall_arrayref('SELECT * FROM test.issue_30');
   is(scalar @$res, 66, 'Non-tab restore replicates by default');

   # Make doubly sure that for a restore that defaults to bin-log
   # that --no-bin-log truly prevents binary logging/replication.
   diag(`/tmp/12345/use -e 'DROP TABLE IF EXISTS test.issue_30'`);
   $res = $dbh->selectall_arrayref('SHOW MASTER STATUS');
   $master_pos = $res->[0]->[1];

   `$cmd --no-bin-log /tmp/default/`;
   sleep 1;

   $slave_dbh->do('USE test');
   $res = $slave_dbh->selectall_arrayref('SHOW TABLES LIKE "issue_30"');
   ok(!scalar @$res, 'Non-tab restore does not replicate with --no-bin-log');

   $res = $dbh->selectall_arrayref('SHOW MASTER STATUS');
   is($master_pos, $res->[0]->[1], 'Bin log pos unchanged');

   # Check that triggers are not replicated
   `$cmd ./samples/tbls_with_trig/ --no-bin-log`;
   sleep 1;

   $slave_dbh->do('USE test');
   $res = $slave_dbh->selectall_arrayref('SHOW TRIGGERS');
   is_deeply($res, [], 'Triggers are not replicated with --no-bin-log');
   $res = $dbh->selectall_arrayref('SHOW MASTER STATUS');
   is($master_pos, $res->[0]->[1], 'Bin log pos unchanged');
};

# #############################################################################
# Issue 406: Use of uninitialized value in concatenation (.) or string at
# ./mk-parallel-restore line 1808
# #############################################################################
$sb->load_file('master', 'samples/issue_30.sql');
$output = `MKDEBUG=1 $cmd -D test /tmp/default/ 2>&1`;
unlike(
   $output,
   qr/uninitialized value/,
   'No error restoring table that already exists (issue 406)'
);
like(
   $output,
   qr/1 tables,\s+3 files,\s+1 successes,\s+0 failures/,
   'Restoring table that already exists (issue 406)'
);

# #############################################################################
# Done.
# #############################################################################
`rm -rf /tmp/default/`;
$sb->wipe_clean($dbh);
exit;
