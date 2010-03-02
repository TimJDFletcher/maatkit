#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

use MaatkitTest;
use QueryAdvisorRules;
use QueryAdvisor;
use PodParser;

# This module's purpose is to run rules and return a list of the IDs of the
# triggered rules.  It should be very simple.  (But we don't want to put the two
# modules together.  Their purposes are distinct.)
my $p   = new PodParser();
my $qar = new QueryAdvisorRules(PodParser => $p);
my $qa  = new QueryAdvisor();

# This should make $qa internally call get_rules() on $qar and save the rules
# into its own list.  If the user plugs in his own module, we'd call
# load_rules() on that too, and just append the rules (with checks that they
# don't redefine any rule IDs).
$qa->load_rules($qar);

# To test the above, we ask it to load the same rules twice.  It should die with
# an error like "Rule LIT.001 already exists, and cannot be redefined"
throws_ok (
   sub { $qa->load_rules($qar) },
   qr/Rule \S+ already exists and cannot be redefined/,
   'Duplicate rules are caught',
);

# We'll also load the rule info, so we can test $qa->get_rule_info() after the
# POD is loaded.
$qar->load_rule_info(
   rules   => [ $qar->get_rules() ],
   file    => "$trunk/mk-query-advisor/mk-query-advisor",
   section => 'RULES',
);

# This should make $qa call $qar->get_rule_info('....') for every rule ID it
# has, and store the info, and make sure that nothing is redefined.  A user
# shouldn't be able to load a plugin that redefines the severity/desc of a
# built-in rule.  Maybe we'll provide a way to override that, though by default
# we want to warn and be strict.
$qa->load_rule_info($qar);

# TODO: write a test that the rules are described as defined in the POD of the
# tool.  Testing one rule should be enough.

# Test that it can't be redefined...
throws_ok (
   sub { $qa->load_rule_info($qar) },
   qr/Info for rule \S+ already exists and cannot be redefined/,
   'Duplicate rule info is caught',
);

is_deeply(
   $qa->get_rule_info('ALI.001'),
   {
      id          => 'ALI.001',
      severity    => 'NOTE',
      description => 'Alias without AS. Explicit column or table aliases like "tbl AS alias" are preferred to implicit aliases like "tbl alias".',
   },
   'get_rule_info()'
);

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $p->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
