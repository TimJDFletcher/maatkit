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
require "$trunk/mk-archiver/mk-archiver";

my $dp   = new DSNParser();
my $sb   = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh  = $sb->get_dbh_for('master');
my $dbh2 = $sb->get_dbh_for('slave1');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$dbh2 ) {
   plan skip_all => 'Cannot connect to sandbox slave';
}
else {
   plan tests => 6;
}

$sb->wipe_clean($dbh);
$sb->wipe_clean($dbh2);

my $output;
my $sql;
my $cnf = "/tmp/12345/my.sandbox.cnf";
my $cmd = "$trunk/mk-archiver/mk-archiver";

# #############################################################################
# Issue 758: Make mk-archiver wait for a slave
# #############################################################################
$sb->load_file('master', 'mk-archiver/t/samples/issue_758.sql');

is_deeply(
   $dbh->selectall_arrayref('select * from issue_758.t'),
   [[1],[2]],
   'Table not purged yet (issue 758)'
);

# Once this goes through repl, the slave will sleep causing
# seconds behind master to increase > 0.
system('/tmp/12345/use -e "insert into issue_758.t select sleep(2)"');

# Slave seems to be lagging now so the first row should get purged
# immediately, then the script should wait about 2 seconds until
# slave lag is gone.
system("$cmd --source F=$cnf,D=issue_758,t=t --purge --where 'i>0' --check-slave-lag h=127.1,P=12346,u=msandbox,p=msandbox >/dev/null 2>&1 &");

sleep 1;
is_deeply(
   $dbh2->selectall_arrayref('select * from issue_758.t'),
   [[1],[2]],
   'No changes on slave yet (issue 758)'
);

is_deeply(
   $dbh->selectall_arrayref('select * from issue_758.t'),
   [[0],[2]],
   'First row purged (issue 758)'
);

# The script it waiting for slave lag so no more rows should be purged yet.
sleep 1;
is_deeply(
   $dbh->selectall_arrayref('select * from issue_758.t'),
   [[0],[2]],
   'Still only first row purged (issue 758)'
);

# After this sleep the slave should have executed the INSERT SELECT,
# which returns 0, and the 2 purge/delete statments from above.
sleep 1;
is_deeply(
   $dbh->selectall_arrayref('select * from issue_758.t'),
   [[0]],
   'Final table state on master (issue 758)'
);

is_deeply(
   $dbh2->selectall_arrayref('select * from issue_758.t'),
   [[0]],
   'Final table state on slave (issue 758)'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
$sb->wipe_clean($dbh2);
exit;
