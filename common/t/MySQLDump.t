#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 12;

use MySQLDump;
use Quoter;
use DSNParser;
use Sandbox;
use MaatkitTest;

my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

$sb->create_dbs($dbh, ['test']);

my $du = new MySQLDump();
my $q  = new Quoter();

my $dump;

# TODO: get_create_table() seems to return an arrayref sometimes!

SKIP: {
   skip 'Sandbox master does not have the sakila database', 10
      unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   $dump = $du->dump($dbh, $q, 'sakila', 'film', 'table');
   like($dump, qr/language_id/, 'Dump sakila.film');

   $dump = $du->dump($dbh, $q, 'mysql', 'film', 'triggers');
   ok(!defined $dump, 'no triggers in mysql');

   $dump = $du->dump($dbh, $q, 'sakila', 'film', 'triggers');
   like($dump, qr/AFTER INSERT/, 'dump triggers');

   $dump = $du->dump($dbh, $q, 'sakila', 'customer_list', 'table');
   like($dump, qr/CREATE TABLE/, 'Temp table def for view/table');
   like($dump, qr/DROP TABLE/, 'Drop temp table def for view/table');
   like($dump, qr/DROP VIEW/, 'Drop view def for view/table');
   unlike($dump, qr/ALGORITHM/, 'No view def');

   $dump = $du->dump($dbh, $q, 'sakila', 'customer_list', 'view');
   like($dump, qr/DROP TABLE/, 'Drop temp table def for view');
   like($dump, qr/DROP VIEW/, 'Drop view def for view');
   like($dump, qr/ALGORITHM/, 'View def');
};

# #############################################################################
# Issue 170: mk-parallel-dump dies when table-status Data_length is NULL
# #############################################################################

# The underlying problem for issue 170 is that MySQLDump doesn't eval some
# of its queries so when MySQLFind uses it and hits a broken table it dies.

diag(`cp $trunk/mk-parallel-dump/t/samples/broken_tbl.frm /tmp/12345/data/test/broken_tbl.frm`);
my $output = '';
eval {
   local *STDERR;
   open STDERR, '>', \$output;
   $dump = $du->dump($dbh, $q, 'test', 'broken_tbl', 'table');
};
is(
   $EVAL_ERROR,
   '',
   'No error dumping broken table'
);
like(
   $output,
   qr/table may be damaged.+selectrow_hashref failed/s,
   'Warns about possibly damaged table'
);

$sb->wipe_clean($dbh);
exit;
