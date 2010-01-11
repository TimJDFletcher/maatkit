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
require "$trunk/mk-log-player/mk-log-player";

my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 2;
}

# #############################################################################
# Issue 799: Can --set-vars unset @@SQL_MODE='NO_AUTO_VALUE_ON_ZERO'?
# #############################################################################

$sb->load_file('master', 'mk-log-player/t/samples/issue_799.sql');

my $output;
$output = `$trunk/mk-log-player/mk-log-player --threads 1 --play $trunk/mk-log-player/t/samples/issue_799.txt h=127.1,P=12345,u=msandbox,p=msandbox 2>/dev/null`;

is_deeply(
   $dbh->selectall_arrayref('select * from issue_799.t'),
   [[0]],
   "Default \@\@SQL_MODE='NO_AUTO_VALUE_ON_ZERO'"
);

$sb->load_file('master', 'mk-log-player/t/samples/issue_799.sql');

$output = `$trunk/mk-log-player/mk-log-player --threads 1 --play $trunk/mk-log-player/t/samples/issue_799.txt h=127.1,P=12345,u=msandbox,p=msandbox --set-vars \@\@SQL_MODE="''"`;

is_deeply(
   $dbh->selectall_arrayref('select * from issue_799.t'),
   [[1]],
   '--set-vars @@SQL_MODE=\'\' unsets default'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
diag(`rm -rf ./session-results-*`);
exit;
