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
require "$trunk/mk-duplicate-key-checker/mk-duplicate-key-checker";

my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 8;
}

my $output;
my $cnf = "/tmp/12345/my.sandbox.cnf";
my $cmd = "$trunk/mk-duplicate-key-checker/mk-duplicate-key-checker -F $cnf -h 127.1";

$sb->wipe_clean($dbh);
$sb->create_dbs($dbh, ['test']);

$output = `$cmd -d mysql -t columns_priv -v`;
like($output,
   qr/PRIMARY \(`Host`,`Db`,`User`,`Table_name`,`Column_name`\)/,
   'Finds mysql.columns_priv PK'
);

is(`$cmd -d test --nosummary`, '', 'No dupes on clean sandbox');

$sb->load_file('master', 'common/t/samples/dupe_key.sql', 'test');

ok(
   no_diff("$cmd -d test", 'mk-duplicate-key-checker/t/samples/basic_output.txt'),
   'Default output'
);

ok(
   no_diff("$cmd -d test --nosql", 'mk-duplicate-key-checker/t/samples/nosql_output.txt'),
   '--nosql'
);

ok(
   no_diff("$cmd -d test --nosummary", 'mk-duplicate-key-checker/t/samples/nosummary_output.txt'),
   '--nosummary'
);

$sb->load_file('master', 'common/t/samples/uppercase_names.sql', 'test');

ok(
   no_diff("$cmd -d test -t UPPER_TEST", 'mk-duplicate-key-checker/t/samples/uppercase_names.txt'),
   'Issue 306 crash on uppercase column names'
);

$sb->load_file('master', 'common/t/samples/issue_269-1.sql', 'test');

ok(
   no_diff("$cmd -d test -t a", 'mk-duplicate-key-checker/t/samples/issue_269.txt'),
   'No dupes for issue 269'
);

$sb->wipe_clean($dbh);

ok(
   no_diff("$cmd -d test", 'mk-duplicate-key-checker/t/samples/nonexistent_db.txt'),
   'No results for nonexistent db'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;