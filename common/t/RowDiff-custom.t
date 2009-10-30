#!/usr/bin/perl -w

# RowDiff-custom.t tests some of the basic RowDiff functionalities
# as RowDiff.t but uses a different Perl lib if the MK_PERL_LIB
# environment var is set. This allows us to test these functionalities
# against custom versions of DBI, DBD::mysql, etc. If MK_PERL_LIB
# is not set, then all these tests are skipped.

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

# #############################################################################

package main;
BEGIN {
   if ( defined $ENV{MK_PERL_LIB} ) {
      die "The MK_PERL_LIB environment variable is not a valid directory: "
         . $ENV{MK_PERL_LIB}
         if !-d $ENV{MK_PERL_LIB};

      print "# Using Perl lib $ENV{MK_PERL_LIB}\n";
      use lib ($ENV{MK_PERL_LIB} ? "$ENV{MK_PERL_LIB}" : ());
   }
};
use strict;
use warnings FATAL => 'all';

use Test::More tests => 4;
use English qw(-no_match_vars);
use DBI;
use DBD::mysql;  # so we can print $DBD::mysql::VERSION

SKIP: {
   skip "MK_PERL_LIB env var is not set", 4 unless defined $ENV{MK_PERL_LIB};

   print "# DBI v$DBI::VERSION\n"
      . "# DBD::mysql v$DBD::mysql::VERSION\n";


   require '../RowDiff.pm';
   require '../Sandbox.pm';
   require '../DSNParser.pm';
   require '../TableParser.pm';
   require '../MySQLDump.pm';
   require '../Quoter.pm';

   my $d  = new RowDiff(dbh => 1);
   my $s  = new MockSync();
   my $q  = new Quoter();
   my $du = new MySQLDump();
   my $tp = new TableParser(Quoter => $q);
   my $dp = new DSNParser();

   # Connect to sandbox now to make sure it's running.
   my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
   my $master_dbh = $sb->get_dbh_for('master')
      or BAIL_OUT('Cannot connect to sandbox master');
   my $slave_dbh  = $sb->get_dbh_for('slave1')
      or BAIL_OUT('Cannot connect to sandbox slave');

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
};
exit;
