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
require "$trunk/mk-table-checksum/mk-table-checksum";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 1;
}

my $output;
my $cnf = '/tmp/12345/my.sandbox.cnf';

# #############################################################################
# Issue 947: mk-table-checksum crashes if h DSN part is not given
# #############################################################################

$output = output(
   sub { mk_table_checksum::main("F=$cnf", qw(-d mysql -t user)) },
   undef,
   stderr   => 1,
);
is(
   $output,
"DATABASE TABLE CHUNK HOST  ENGINE      COUNT         CHECKSUM TIME WAIT STAT  LAG
mysql    user      0 dante MyISAM       NULL        878853993    0    0 NULL NULL
",
   "Doesn't crash if no h DSN part (issue 947)"
);

# #############################################################################
# Done.
# #############################################################################
exit;
