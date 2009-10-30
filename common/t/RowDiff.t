#!/usr/bin/perl

# This program is copyright (c) 2007 Baron Schwartz.
# Feedback and improvements are welcome.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
# systems, you can issue `man perlgpl' or `man perlartistic' to read these
# licenses.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA.
use strict;
use warnings FATAL => 'all';

# A package to mock up a syncer
package MockSync;

sub new {
   return bless [], shift;
}

sub same_row {
   my ( $self, $lr, $rr ) = @_;
   push @$self, 'same';
}

sub not_in_right {
   my ( $self, $lr ) = @_;
   push @$self, [ 'not in right', $lr];
}

sub not_in_left {
   my ( $self, $rr ) = @_;
   push @$self, [ 'not in left', $rr];
}

sub done_with_rows {
   my ( $self ) = @_;
   push @$self, 'done';
}

sub key_cols {
   return [qw(a)];
}

package main;

my $tests;
BEGIN {
   $tests = 26;
}

use Test::More tests => $tests;
use English qw(-no_match_vars);
use DBI;

require '../RowDiff.pm';
require '../MockSth.pm';
require '../Sandbox.pm';
require '../DSNParser.pm';
require '../TableParser.pm';
require '../MySQLDump.pm';
require '../Quoter.pm';

use Data::Dumper;
$Data::Dumper::Indent=1;

sub throws_ok {
   my ( $code, $pat, $msg ) = @_;
   eval { $code->(); };
   like ( $EVAL_ERROR, $pat, $msg );
}

my ( $d, $s );


my $q  = new Quoter();
my $du = new MySQLDump();
my $tp = new TableParser(Quoter => $q);
my $dp = new DSNParser();

# Connect to sandbox now to make sure it's running.
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');
my $slave_dbh  = $sb->get_dbh_for('slave1');


throws_ok( sub { new RowDiff() }, qr/I need a dbh/, 'DBH required' );
$d = new RowDiff(dbh => 1);

is(
   $d->key_cmp( { a => 1 }, { a => 1 }, [qw(a)], {},),
   0,
   'Equal keys',
);

is(
   $d->key_cmp( { a => undef }, { a => undef }, [qw(a)], {},),
   0,
   'Equal null keys',
);

is(
   $d->key_cmp( undef, { a => 1 }, [qw(a)], {},),
   -1,
   'Left key missing',
);

is(
   $d->key_cmp( { a => 1 }, undef, [qw(a)], {},),
   1,
   'Right key missing',
);

is(
   $d->key_cmp( { a => 2 }, { a => 1 }, [qw(a)], {},),
   1,
   'Right key smaller',
);

is(
   $d->key_cmp( { a => 2 }, { a => 3 }, [qw(a)], {},),
   -1,
   'Right key larger',
);

is(
   $d->key_cmp( { a => 1, b => 2, }, { a => 1, b => 1 }, [qw(a b)], {},),
   1,
   'Right two-part key smaller',
);

is(
   $d->key_cmp( { a => 1, b => 0, }, { a => 1, b => 1 }, [qw(a b)], {},),
   -1,
   'Right two-part key larger',
);

is(
   $d->key_cmp( { a => 1, b => undef, }, { a => 1, b => 1 }, [qw(a b)], {},),
   -1,
   'Right two-part key larger because of null',
);

is(
   $d->key_cmp( { a => 1, b => 0, }, { a => 1, b => undef }, [qw(a b)], {},),
   1,
   'Left two-part key larger because of null',
);

is(
   $d->key_cmp( { a => 1, b => 0, }, { a => undef, b => 1 }, [qw(a b)], {},),
   1,
   'Left two-part key larger because of null in first key part',
);

$s = new MockSync();
$d->compare_sets(
   left => new MockSth(
   ),
   right => new MockSth(
   ),
   syncer => $s,
   tbl => {},
);
is_deeply(
   $s,
   [
      'done',
   ],
   'no rows',
);

$s = new MockSync();
$d->compare_sets(
   left => new MockSth(
   ),
   right => new MockSth(
      { a => 1, b => 2, c => 3 },
   ),
   syncer => $s,
   tbl => {},
);
is_deeply(
   $s,
   [
      [ 'not in left', { a => 1, b => 2, c => 3 },],
      'done',
   ],
   'right only',
);

$s = new MockSync();
$d->compare_sets(
   left => new MockSth(
      { a => 1, b => 2, c => 3 },
   ),
   right => new MockSth(
   ),
   syncer => $s,
   tbl => {},
);
is_deeply(
   $s,
   [
      [ 'not in right', { a => 1, b => 2, c => 3 },],
      'done',
   ],
   'left only',
);

$s = new MockSync();
$d->compare_sets(
   left => new MockSth(
      { a => 1, b => 2, c => 3 },
   ),
   right => new MockSth(
      { a => 1, b => 2, c => 3 },
   ),
   syncer => $s,
   tbl => {},
);
is_deeply(
   $s,
   [
      'same',
      'done',
   ],
   'one identical row',
);

$s = new MockSync();
$d->compare_sets(
   left => new MockSth(
      { a => 1, b => 2, c => 3 },
      { a => 2, b => 2, c => 3 },
      { a => 3, b => 2, c => 3 },
      # { a => 4, b => 2, c => 3 },
   ),
   right => new MockSth(
      # { a => 1, b => 2, c => 3 },
      { a => 2, b => 2, c => 3 },
      { a => 3, b => 2, c => 3 },
      { a => 4, b => 2, c => 3 },
   ),
   syncer => $s,
   tbl => {},
);
is_deeply(
   $s,
   [
      [ 'not in right',  { a => 1, b => 2, c => 3 }, ],
      'same',
      'same',
      [ 'not in left', { a => 4, b => 2, c => 3 }, ],
      'done',
   ],
   'differences in basic set of rows',
);

$s = new MockSync();
$d->compare_sets(
   left => new MockSth(
      { a => 1, b => 2, c => 3 },
   ),
   right => new MockSth(
      { a => 1, b => 2, c => 3 },
   ),
   syncer => $s,
   tbl => { is_numeric => { a => 1 } },
);
is_deeply(
   $s,
   [
      'same',
      'done',
   ],
   'Identical with numeric columns',
);

$d = new RowDiff(dbh => $master_dbh);
$s = new MockSync();
$d->compare_sets(
   left => new MockSth(
      { a => 'A', b => 2, c => 3 },
   ),
   right => new MockSth(
      # The difference is the lowercase 'a', which in a _ci collation will
      # sort the same.  So the rows are really identical, from MySQL's point
      # of view.
      { a => 'a', b => 2, c => 3 },
   ),
   syncer => $s,
   tbl => { collation_for => { a => 'utf8_general_ci' } },
);
is_deeply(
   $s,
   [
      'same',
      'done',
   ],
   'Identical with utf8 columns',
);


# #############################################################################
# Test that the callbacks work.
# #############################################################################
my @rows;
my $same_row     = sub {
   push @rows, 'same row';
};
my $not_in_left  = sub {
   push @rows, 'not in left';
};
my $not_in_right = sub {
   push @rows, 'not in right';
};
my $key_cmp = sub {
   my ( $col, $lr, $rr ) = @_;
   push @rows, "col $col differs";
};

$s = new MockSync();
$d = new RowDiff(
   dbh          => 1,
   key_cmp      => $key_cmp,
   same_row     => $same_row,
   not_in_left  => $not_in_left,
   not_in_right => $not_in_right,
);
@rows = ();
$d->compare_sets(
   left => new MockSth(
      { a => 1, b => 2, c => 3 },
      { a => 2, b => 2, c => 3 },
      { a => 3, b => 2, c => 3 },
      # { a => 4, b => 2, c => 3 },
   ),
   right => new MockSth(
      # { a => 1, b => 2, c => 3 },
      { a => 2, b => 2, c => 3 },
      { a => 3, b => 2, c => 3 },
      { a => 4, b => 2, c => 3 },
   ),
   syncer => $s,
   tbl => {},
);
is_deeply(
   \@rows,
   [
      'col a differs',
      'not in right',
      'same row',
      'same row',
      'not in left',
   ],
   'callbacks'
);

my $i = 0;
$d = new RowDiff(
   dbh          => 1,
   key_cmp      => $key_cmp,
   same_row     => $same_row,
   not_in_left  => $not_in_left,
   not_in_right => $not_in_right,
   done         => sub { return ++$i > 2 ? 1 : 0; },
);
@rows = ();
$d->compare_sets(
   left => new MockSth(
      { a => 1, b => 2, c => 3 },
      { a => 2, b => 2, c => 3 },
      { a => 3, b => 2, c => 3 },
      # { a => 4, b => 2, c => 3 },
   ),
   right => new MockSth(
      # { a => 1, b => 2, c => 3 },
      { a => 2, b => 2, c => 3 },
      { a => 3, b => 2, c => 3 },
      { a => 4, b => 2, c => 3 },
   ),
   syncer => $s,
   tbl => {},
);
is_deeply(
   \@rows,
   [
      'col a differs',
      'not in right',
      'same row',
      'same row',
   ],
   'done callback'
);

$d = new RowDiff(
   dbh          => 1,
   key_cmp      => $key_cmp,
   same_row     => $same_row,
   not_in_left  => $not_in_left,
   not_in_right => $not_in_right,
   trf          => sub {
      my ( $l, $r, $tbl, $col ) = @_;
      return 1, 1;  # causes all rows to look like they're identical
   },
);
@rows = ();
$d->compare_sets(
   left => new MockSth(
      { a => 1, b => 2, c => 3 },
      { a => 4, b => 5, c => 6 },
   ),
   right => new MockSth(
      { a => 7,  b => 8,  c => 9  },
      { a => 10, b => 11, c => 12 },
   ),
   syncer => $s,
   tbl => { is_numeric => { a => 1, b => 1, c => 1 } },
);
is_deeply(
   \@rows,
   [
      'same row',
      'same row',
   ],
   'trf callback'
);

# #############################################################################
# The following tests use "real" (sandbox) servers and real statement handles.
# #############################################################################

$d = new RowDiff(dbh => $master_dbh);

$sb->create_dbs($master_dbh, [qw(test)]);
$sb->load_file('master', 'samples/issue_11.sql');

my $tbl = $tp->parse(
   $du->get_create_table($master_dbh, $q, 'test', 'issue_11'));

my $left_sth  = $master_dbh->prepare('SELECT * FROM test.issue_11');
my $right_sth = $slave_dbh->prepare('SELECT * FROM test.issue_11');
$left_sth->execute();
$right_sth->execute();
$s = new MockSync();
$d->compare_sets(
   left  => $left_sth,
   right => $right_sth,
   syncer => $s,
   tbl => $tbl,
);
is_deeply(
   $s,
   ['done',],
   'no rows (real DBI sth)',
);

$slave_dbh->do('INSERT INTO test.issue_11 VALUES (1,2,3)');
$left_sth  = $master_dbh->prepare('SELECT * FROM test.issue_11');
$right_sth = $slave_dbh->prepare('SELECT * FROM test.issue_11');
$left_sth->execute();
$right_sth->execute();
$s = new MockSync();
$d->compare_sets(
   left   => $left_sth,
   right  => $right_sth,
   syncer => $s,
   tbl    => $tbl,
);
is_deeply(
   $s,
   [
      ['not in left', { a => 1, b => 2, c => 3 },],
      'done',
   ],
   'right only (real DBI sth)',
);

$slave_dbh->do('TRUNCATE TABLE test.issue_11');
$master_dbh->do('SET SQL_LOG_BIN=0;');
$master_dbh->do('INSERT INTO test.issue_11 VALUES (1,2,3)');
$left_sth  = $master_dbh->prepare('SELECT * FROM test.issue_11');
$right_sth = $slave_dbh->prepare('SELECT * FROM test.issue_11');
$left_sth->execute();
$right_sth->execute();
$s = new MockSync();
$d->compare_sets(
   left   => $left_sth,
   right  => $right_sth,
   syncer => $s,
   tbl    => $tbl,
);
is_deeply(
   $s,
   [
      [ 'not in right', { a => 1, b => 2, c => 3 },],
      'done',
   ],
   'left only (real DBI sth)',
);

$slave_dbh->do('INSERT INTO test.issue_11 VALUES (1,2,3)');
$left_sth  = $master_dbh->prepare('SELECT * FROM test.issue_11');
$right_sth = $slave_dbh->prepare('SELECT * FROM test.issue_11');
$left_sth->execute();
$right_sth->execute();
$s = new MockSync();
$d->compare_sets(
   left   => $left_sth,
   right  => $right_sth,
   syncer => $s,
   tbl    => $tbl,
);
is_deeply(
   $s,
   [
      'same',
      'done',
   ],
   'one identical row (real DBI sth)',
);

$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
