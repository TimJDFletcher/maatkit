#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 18;

require "../ChangeHandler.pm";
require "../Quoter.pm";
require '../DSNParser.pm';
require '../Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

my $dbh = $sb->get_dbh_for('master');

sub throws_ok {
   my ( $code, $pat, $msg ) = @_;
   eval { $code->(); };
   like ( $EVAL_ERROR, $pat, $msg );
}

throws_ok(
   sub { new ChangeHandler() },
   qr/I need a Quoter/,
   'Needs a Quoter',
);

my @rows;
my $q  = new Quoter();
my $ch = new ChangeHandler(
   Quoter  => $q,
   dst_db  => 'test',
   dst_tbl => 'foo',
   src_db  => 'test',
   src_tbl => 'test1',
   actions => [ sub { push @rows, @_ } ],
   replace => 0,
   queue   => 0,
);

$ch->change('INSERT', { a => 1, b => 2 }, [qw(a)] );

is_deeply(\@rows,
   ['INSERT INTO `test`.`foo`(`a`, `b`) VALUES (1, 2)',],
   'First row',
);

$ch->{queue} = 1;

$ch->change('DELETE', { a => 1, b => 2 }, [qw(a)] );

is_deeply(\@rows,
   ['INSERT INTO `test`.`foo`(`a`, `b`) VALUES (1, 2)',],
   'Second row not there yet',
);

$ch->process_rows(1);

is_deeply(\@rows,
   [
   'INSERT INTO `test`.`foo`(`a`, `b`) VALUES (1, 2)',
   'DELETE FROM `test`.`foo` WHERE `a`=1 LIMIT 1',
   ],
   'Second row there',
);
$ch->{queue} = 2;

$ch->change('UPDATE', { a => 1, b => 2 }, [qw(a)] );
$ch->process_rows(1);

is_deeply(\@rows,
   [
   'INSERT INTO `test`.`foo`(`a`, `b`) VALUES (1, 2)',
   'DELETE FROM `test`.`foo` WHERE `a`=1 LIMIT 1',
   ],
   'Third row not there',
);

$ch->process_rows();

is_deeply(\@rows,
   [
   'INSERT INTO `test`.`foo`(`a`, `b`) VALUES (1, 2)',
   'DELETE FROM `test`.`foo` WHERE `a`=1 LIMIT 1',
   'UPDATE `test`.`foo` SET `b`=2 WHERE `a`=1 LIMIT 1',
   ],
   'All rows',
);

is_deeply(
   { $ch->get_changes() },
   { REPLACE => 0, DELETE => 1, INSERT => 1, UPDATE => 1 },
   'Changes were recorded',
);

SKIP: {
   skip 'Cannot connect to sandbox master', 1 unless $dbh;

   $dbh->do('CREATE DATABASE IF NOT EXISTS test');

   @rows = ();
   $ch->{queue} = 0;
   $ch->fetch_back($dbh);
   `/tmp/12345/use < samples/before-TableSyncChunk.sql`;
   # This should cause it to fetch the row from test.test1 where a=1
   $ch->change('UPDATE', { a => 1, __foo => 'bar' }, [qw(a)] );
   $ch->change('DELETE', { a => 1, __foo => 'bar' }, [qw(a)] );
   $ch->change('INSERT', { a => 1, __foo => 'bar' }, [qw(a)] );
   is_deeply(
      \@rows,
      [
         "UPDATE `test`.`foo` SET `b`='en' WHERE `a`=1 LIMIT 1",
         "DELETE FROM `test`.`foo` WHERE `a`=1 LIMIT 1",
         "INSERT INTO `test`.`foo`(`a`, `b`) VALUES (1, 'en')",
      ],
      'Fetch-back',
   );
}

# #############################################################################
# Issue 371: Make mk-table-sync preserve column order in SQL
# #############################################################################
my $row = {
   id  => 1,
   foo => 'foo',
   bar => 'bar',
};
my $tbl_struct = {
   col_posn => { id=>0, foo=>1, bar=>2 },
};
$ch = new ChangeHandler(
   Quoter     => $q,
   dst_db     => 'test',
   dst_tbl    => 'issue_371',
   src_db     => 'test',
   src_tbl    => 'issue_371',
   actions    => [ sub { push @rows, @_ } ],
   replace    => 0,
   queue      => 0,
   tbl_struct => $tbl_struct,
);

is(
   $ch->make_INSERT($row, [qw(id foo bar)]),
   "INSERT INTO `test`.`issue_371`(`id`, `foo`, `bar`) VALUES (1, 'foo', 'bar')",
   'make_INSERT() preserves column order'
);

is(
   $ch->make_REPLACE($row, [qw(id foo bar)]),
   "REPLACE INTO `test`.`issue_371`(`id`, `foo`, `bar`) VALUES (1, 'foo', 'bar')",
   'make_REPLACE() preserves column order'
);

is(
   $ch->make_UPDATE($row, [qw(id foo)]),
   "UPDATE `test`.`issue_371` SET `bar`='bar' WHERE `id`=1 AND `foo`='foo' LIMIT 1",
   'make_UPDATE() preserves column order'
);

is(
   $ch->make_DELETE($row, [qw(id foo bar)]),
   "DELETE FROM `test`.`issue_371` WHERE `id`=1 AND `foo`='foo' AND `bar`='bar' LIMIT 1",
   'make_DELETE() preserves column order'
);

# Test what happens if the row has a column that not in the tbl struct.
$row->{other_col} = 'zzz';

is(
   $ch->make_INSERT($row, [qw(id foo bar)]),
   "INSERT INTO `test`.`issue_371`(`id`, `foo`, `bar`, `other_col`) VALUES (1, 'foo', 'bar', 'zzz')",
   'make_INSERT() preserves column order, with col not in tbl'
);

is(
   $ch->make_REPLACE($row, [qw(id foo bar)]),
   "REPLACE INTO `test`.`issue_371`(`id`, `foo`, `bar`, `other_col`) VALUES (1, 'foo', 'bar', 'zzz')",
   'make_REPLACE() preserves column order, with col not in tbl'
);

is(
   $ch->make_UPDATE($row, [qw(id foo)]),
   "UPDATE `test`.`issue_371` SET `bar`='bar', `other_col`='zzz' WHERE `id`=1 AND `foo`='foo' LIMIT 1",
   'make_UPDATE() preserves column order, with col not in tbl'
);

delete $row->{other_col};

SKIP: {
   skip 'Cannot connect to sandbox master', 3 unless $dbh;

   $dbh->do('DROP TABLE IF EXISTS test.issue_371');
   $dbh->do('CREATE TABLE test.issue_371 (id INT, foo varchar(16), bar char)');
   $dbh->do('INSERT INTO test.issue_371 VALUES (1,"foo","a"),(2,"bar","b")');

   $ch->fetch_back($dbh);

   is(
      $ch->make_INSERT($row, [qw(id foo)]),
      "INSERT INTO `test`.`issue_371`(`id`, `foo`, `bar`) VALUES (1, 'foo', 'a')",
      'make_INSERT() preserves column order, with fetch-back'
   );

   is(
      $ch->make_REPLACE($row, [qw(id foo)]),
      "REPLACE INTO `test`.`issue_371`(`id`, `foo`, `bar`) VALUES (1, 'foo', 'a')",
      'make_REPLACE() preserves column order, with fetch-back'
   );

   is(
      $ch->make_UPDATE($row, [qw(id foo)]),
      "UPDATE `test`.`issue_371` SET `bar`='a' WHERE `id`=1 AND `foo`='foo' LIMIT 1",
      'make_UPDATE() preserves column order, with fetch-back'
   );
};

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh) if $dbh;
exit;
