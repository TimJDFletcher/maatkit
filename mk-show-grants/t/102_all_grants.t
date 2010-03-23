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
require "$trunk/mk-show-grants/mk-show-grants";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 2;
}

$sb->wipe_clean($dbh);

my $output;
my $cnf = '/tmp/12345/my.sandbox.cnf';

# #############################################################################
# Issue 551: mk-show-grants does not support listing all grants for a single
# user (over multiple hosts)
# #############################################################################
diag(`/tmp/12345/use -u root -e "GRANT USAGE ON *.* TO 'bob'\@'%'"`);
diag(`/tmp/12345/use -u root -e "GRANT USAGE ON *.* TO 'bob'\@'localhost'"`);
diag(`/tmp/12345/use -u root -e "GRANT USAGE ON *.* TO 'bob'\@'192.168.1.1'"`);

$output = output(
   sub { mk_show_grants::main('-F', $cnf, qw(--only bob --no-header)); }
);
is(
   $output,
"-- Grants for 'bob'\@'%'
GRANT USAGE ON *.* TO 'bob'\@'%';
-- Grants for 'bob'\@'192.168.1.1'
GRANT USAGE ON *.* TO 'bob'\@'192.168.1.1';
-- Grants for 'bob'\@'localhost'
GRANT USAGE ON *.* TO 'bob'\@'localhost';
",
   '--only user gets grants for user on all hosts (issue 551)'
);

$output = output(
   sub { mk_show_grants::main('-F', $cnf, qw(--only bob@192.168.1.1 --no-header)); }
);
is(
   $output,
"-- Grants for 'bob'\@'192.168.1.1'
GRANT USAGE ON *.* TO 'bob'\@'192.168.1.1';
",
   '--only user@host'
);

diag(`/tmp/12345/use -u root -e "DROP USER 'bob'\@'%'"`);
diag(`/tmp/12345/use -u root -e "DROP USER 'bob'\@'localhost'"`);
diag(`/tmp/12345/use -u root -e "DROP USER 'bob'\@'192.168.1.1'"`);

# #############################################################################
# Done.
# #############################################################################
exit;
