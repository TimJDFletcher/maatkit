#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

use VersionParser;
use MaatkitTest;

my $p = new VersionParser;

is(
   $p->parse('5.0.38-Ubuntu_0ubuntu1.1-log'),
   '005000038',
   'Parser works on ordinary version',
);

# Open a connection to MySQL, or skip the rest of the tests.
use DSNParser;
use Sandbox;
my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');
SKIP: {
   skip 'Cannot connect to MySQL', 1 unless $dbh;
   ok($p->version_ge($dbh, '3.23.00'), 'Version is > 3.23');
}

# #############################################################################
# Done.
# #############################################################################
exit;
