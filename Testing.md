#summary How Maatkit testing works

Maatkit has a unit test suite.  The test suite is not packaged with the monthly releases; it is available through a full checkout of the Maatkit svn trunk or a branch.  This wiki explains everything you want to know about Maatkit testing from both a user's and a developer's perspective.

In the near future we will implement and deploy a build farm, most likely using [Buildbot](http://buildbot.net/trac).  For now, though, Maatkit can be tested manually.

The Maatkit test environment ("mk test env") is simple to setup and run.  It requires only:

  1. A machine running MySQL v5.0 or v5.1
  1. A full read-only (or writable) copy of the Maatkit svn trunk or a branch
  1. At least 1 environment variable: `MAATKIT_WORKING_COPY`

Once up and running, the mk test env creates custom, lightweight [MySQL sandbox](http://mysqlsandbox.net/) servers in which it does all its work so your existing MySQL data is not used.

First we'll provide an overview of the sandbox servers that Maatkit uses for its test environment.  Then we'll explain how to configure, start and control the mk test env.  Once its running, we'll explain how to test Maakit.

# Maatkit's Sandbox Servers #

Maatkit's sandbox servers are like real [MySQL sandbox](http://mysqlsandbox.net/) servers, but for various technical reasons Maatkit does not use or require the real MySQL sandbox.  Maatkit provides all of its own sandbox control scripts.

Each Maakit sandbox server is created in `/tmp/1234?`, running on respective ports.  The main sandbox servers are a master on port 12345 (`/tmp/12345`) and a slave on port 12346 (`/tmp/12346`).  Some tests will create and destroy other sandbox servers as needed.

Here's the list of sandbox servers that Maatkit uses:

| **Server** | **Port and /tmp** | **Usage** |
|:-----------|:------------------|:----------|
| master     | 12345             | main sandbox, always up |
| slave      | 12346             | main slave to main master, always up |
| alt1       | 12347             | another master or slave |
| alt2       | 12348             | another master or slave; OR... |
| mm1        | 12348             | first master in master-master replication |
| mm2        | 12349             | second master in master-master replication |
| ms-master  | 2900              | MasterSlave.t master |
| ms-slave0  | 2901              | MasterSlave.t slave0 |
| ms-slave1  | 2902              | MasterSlave.t slave1 |
| ms-slave2  | 2903              | MasterSlave.t slave2 |

Every sandbox server has the same MySQL user name and password: msandbox.  The root account has no password.  The tests mostly run as msandbox, but sometimes they use root or create and destroy other privs.

# Configuring the Maatkit Test Environment #

Maatkit is only officially tested on MySQL v5.0 and v5.1, but sandboxes exists for v3.23, v4.0 and v4.1.  The mk test env will not run if it detects another version (e.g. currently there is not sandbox for v5.5).  Official support for other versions may increase in the future if enough support is found behind the effort.

Configuring and running the Maatkit test environment requires very little.  In brief:

  1. Choose your MySQL
  1. Checkout Maatkit from svn
  1. Set `MAATKIT_WORKING_COPY` environment variable
  1. Verify and start the test env with `mk-test-env`

## 1. Choose Your MySQL ##

You can use either an existing installation of MySQL (i.e. the one already running on your machine) or download and use a specific binary.  Using an existing installation requires less work, but using a specific binary can allow you to test Maatkit on--for example--MySQL v5.1 even though your machine is running MySQL v5.0.  We'll explain both scenarios.

### Existing Installation ###

The primary thing you must ensure is that whatever user account you use to do Maatkit testing has `mysqld` in its `PATH`.  That means, the user should be able to,

```
daniel@dante:~/dev/maatkit/sandbox$ which mysqld
/usr/sbin/mysqld
```

In my case (standard Ubuntu 9.04), MySQL is installed under `/usr`.  This allows the scripts to determine MySQL's `basedir` and version.

If `mysqld` is not in your `PATH` then you'll need to set the `MAATKIT_SANDBOX_BASEDIR` environment variable accordingly.  On CentOS, for example, the `basedir` is usually `/usr`.  On one FreeBSD 7.0 box that I use the `basedir` is `/usr/local`.  When you run `mk-test-env checkconfig` (described later) it will report of the `basedir` is valid or not.

Your existing MySQL data, socket file, PID file, etc. are not used or accessed.  The `basedir` is only used to determine which `mysqld`, `mysqld_safe` and `mysql` to run.  Sandboxes are used for Maatkit's MySQL data, socket, PID, etc.

### Specific Binary ###

To use a specific MySQL binary package for the mk test env, download the package, extract it, and then set the `MAATKIT_SANDBOX_BASEDIR` environment variable to the full path of the extracted package.  Here's an example...

```
$ pwd
/home/daniel/mysql_binaries

$ wget http://dev.mysql.com/get/Downloads/MySQL-5.0/mysql-5.0.88-linux-i686.tar.gz/from/http://mysql.he.net/

$ tar xvfz mysql-5.0.88-linux-i686.tar.gz

$ export MAATKIT_SANDBOX_BASEDIR="/home/daniel/mysql_binaries/mysql-5.0.88-linux-i686"
```

You'll probably want to `export MAATKIT_SANDBOX_BASEDIR` in your `.bashrc` (or whatever login script is appropriate for your machine) if you wish to make this setting persistent, else it will be lost next time you login and the scripts will auto-detect any existing MySQL installation.

In any case, the scripts use an explicitly set `MAATKIT_SANDBOX_BASEDIR`, otherwise they try to auto-detect the basedir of the existing installation.  Later we'll see how to see what the scripts see using `mk-test-env`.

Unlike using an existing installation, the user's `PATH` does not need to include the directory where the specific binary package was extracted.

## 2. Checkout Maatkit from svn ##

You should have already done this after reading [Getting Started](http://code.google.com/p/maatkit/wiki/GettingStarted), but for completeness, here are the instructions again.

To get the entire Maatkit svn trunk, simply run:

```
svn checkout http://maatkit.googlecode.com/svn/trunk/ maatkit-read-only
```

This will checkout/download Maatkit into a directory called `maatkit-read-only`.  You can change `maatkit-read-only` to whatever you like because the scripts use the `MAATKIT_WORKING_COPY` environment variable to discover this directory.

If you're a developer working on a specific branch, then you can checkout just that branch:

```
svn checkout https://maatkit.googlecode.com/svn/branches/<branch name> <local dir> --username gc_user@example.com
```

For simplicity, in this wiki we deal just with trunk.  The [Branch Management](http://code.google.com/p/maatkit/wiki/BranchManagement) wiki discusses how to deal with several working copies, i.e. trunk, a branch, etc.

## 3. Set `MAATKIT_WORKING_COPY` Environment Variable ##

This is the most important environment variable so it should be set in your `.bashrc` (or whatever login script is appropriate for your shell).  It should point to the base directory for the Maatkit svn trunk or branch that you downloaded in the previous step.  For example:

```
$ pwd
/home/daniel/dev

$ svn checkout http://maatkit.googlecode.com/svn/trunk/ maatkit-read-only

$ echo "export MAATKIT_WORKING_COPY=/home/daniel/dev/maatkit-read-only" >> ~daniel/.bashrc
```

Then logout and re-login (or run `export MAATKIT_WORKING_COPY=/home/daniel/dev/maatkit-read-only` on the command line).

For brevity all directories are relative to `MAATKIT_WORKING_COPY` unless otherwise stated.  So `sandbox/` refers to `MAATKIT_WORKING_COPY/sandbox/` or, in this case, `/home/daniel/dev/maatkit-read-only/sandbox/`.

This environment variable used to be called `MAATKIT_TRUNK` when branches were not used.  But now that developers commit to both trunk and branches, whatever svn directory you checkout it actually just a "working copy".  If you're a developer working with trunk and branches, it's important to keep `MAATKIT_WORKING_COPY` set properly; this is discussed in the next wiki, [Branch Management](http://code.google.com/p/maatkit/wiki/BranchManagement).

## 4. Verify and Start with `mk-test-env` ##

The script `sandbox/mk-test-env` is the primary control script for the mk test env.  It has several typical commands:

  * start: start the mk test env
  * stop: stop the mk test env (and remove the sandboxes)
  * restart: stop and start the mk test env
  * reset: reset replication between master (12345) and slave1 (12346)
  * kill: find and kill Maatkit sandbox processes (when stop doesn't work)
  * checkconfig: check the mk test env configuration
  * status: check the status of the mk test env

The last two commands are very helpful for a new setup.  Let's take a look:

```
$ cd ~daniel/dev/maatkit-read-only/sandbox

$ ./mk-test-env checkconfig
MAATKIT_WORKING_COPY=/home/daniel/dev/maatkit-read-only - ok
MAATKIT_SANDBOX_BASEDIR=/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23 - ok
Maatkit test environment config is ok!
```

The mk test env is dead-simple, just 2 environment variables, but `checkconfig` does other checks like making sure that the directories exist, that `MAATKIT_SANDBOX_BASEDIR/bin/mysqladmin` and other needed programs exist, etc.  In fact, `mk-test-env` does a `checkconfig` before every command (but only outputs this information for the `checkconfig` command) and dies if the mk test env config is not ok.

In that example I have explicitly set `MAATKIT_SANDBOX_BASEDIR`.  Let's unset it and see what happens:

```
$ unset MAATKIT_SANDBOX_BASEDIR

$ ./mk-test-env checkconfig
MAATKIT_WORKING_COPY=/home/daniel/dev/maatkit-read-only - ok
MAATKIT_SANDBOX_BASEDIR=/usr - ok (auto-detected)
Maatkit test environment config is ok!
```

Notice that the script auto-detects the basedir of my existing MySQL installation under `/usr`.

If `mk-test-env checkconfig` says the config is ok, then we should be ready to start the test environment.  (This usually does not work if you're running as root, and for security purposes you probably should not be running as root.)  Let's try...

```
$ ./mk-test-env start
Starting Maatkit sandbox 12345... success!
Starting Maatkit sandbox 12346... success!
Loading sakila database...
Maatkit test environment started!
```

If a sandbox server fails to start, see the next section on troubleshooting startup failures.

The 12345 sandbox is a master and the 12346 sandbox is its slave.  Many tests use the sakila database so it gets loaded automatically, too.  The script checks that the MySQL sandboxes are actually alive and responding, so it should be exceptionally rare that success is reported when in fact the sandboxes failed to start.  Since we're good and paranoid, let's double check the status of the mk test env to verify that the sandbox servers are alive and properly configured:

```
$ ./mk-test-env status
Maatkit sandbox master 12345:
  PID file exists - yes
  process 15547 is alive - yes
  MySQL is alive - yes
  sakila db is loaded - yes
Maatkit sandbox slave 12346:
  PID file exists - yes
  process 15622 is alive - yes
  MySQL is alive - yes
  sakila db is loaded - yes
  slave is running - yes
  slave to master 12345 - yes
Maaktit test environment is ok!
```

If ever there is a problem the script will yell "NO" at you, like this:

```
$ /tmp/12346/use -e 'stop slave'

$ ./mk-test-env status
Maatkit sandbox master 12345:
  PID file exists - yes
  process 15547 is alive - yes
  MySQL is alive - yes
  sakila db is loaded - yes
Maatkit sandbox slave 12346:
  PID file exists - yes
  process 15622 is alive - yes
  MySQL is alive - yes
  sakila db is loaded - yes
  slave is running - NO
  slave to master 12345 - yes
Maaktit test environment is invalid.
```

If there's a problem that's not related to the test env config (e.g. replication breaks), then `mk-test-env restart` should get the env going again.  That command stops, removes, and restarts all Maatkit sandbox servers.  If the mk test env is seriously broken and won't work, send an email to the [Maatkit discussion list](http://groups.google.com/group/maatkit-discuss) or comes chat with us in #maatkit on Freenode IRC.

Once the Maatkit test environment is configured and running you're reading to begin testing!

### Troubleshooting Startup Failures ###

A common reason for failure is running as root: the Maatkit sandbox servers will not run as root.  You must be a regular user.

In general, if the Maatkit test env fails to start you'll probably get an error message like:

```
[daniel@dev ~/maatkit-read-only]$ sandbox/mk-test-env start
Starting Maatkit sandbox 12345... failed.
Sandbox master 12345 failed to start.

There was an error starting the Maatkit test environment.
See http://code.google.com/p/maatkit/wiki/Testing for more information.
```

The first thing to do is look at the sandbox server's error log located at `/tmp/PORT/data/HOST.err`.  Look for error messages like:

```
100210 10:18:26 [ERROR] Can't find messagefile '/usr/share/mysql/english/errmsg.sys'
```

On this particular system, the messages were under `/usr/local/share`, so I symlinked `/usr/share/mysql` to `/usr/local/share/mysql`.

There are, of course, myriad reasons why the sandbox server may fail to start.  As I come across common one I'll list them here.  If you encounter and solve a startup failure, please let us know!

# Testing Maatkit #

Testing Maatkit requires that Maatkit test environment is up and running as described above.  We're in the process of developing an automated testing suite.  Until it's ready, the tools and modules can be tested manually.

Also required are a bunch of modules listed in the Perl Modules section of the [Getting Started](http://code.google.com/p/maatkit/wiki/GettingStarted) wiki.  The easiest way to test if your system has all these modules is to run `trunk/maatkit/check-perl-modules`.  Any missing modules will cause an error.  If all modules are installed, then a list of their installed versions will be printed.  It can be helpful to know these versions.

To test anything, just run `prove` in the test directory, or `prove -r` from a parent directory and prove will recurse into any test directory it finds and run all tests therein.  Here are some examples:

  * Test all common modules: `cd trunk/common/t; prove -s`
  * Test one tool, e.g. mk-query-digest: `cd trunk; prove mk-query-digest/t`
  * Test everything: `cd trunk; prove -rs`

Notice that all tests are path-independent.  This is thanks to the `MAATKIT_WORKING_COPY` env var (that's why it's so important it be set).  You can test anything from anywhere.  Also, we like to use `prove -s` so the tests are shuffled and ran in a random order.

On my machine all tools pass all their tests.  Testing on other people's machines is just beginning so we're sure to find new bugs/issues.  Participate in [discussions](http://groups.google.com/group/maatkit-discuss) or comes chat with us in #maatkit on Freenode IRC about your testing experience, successes, failures or suggestions.

Some versions of `prove` do not assume `*.t`:

```
[daniel@dev ~/maatkit-read-only/common/t]$ prove
No tests named and 't' directory not found at /usr/local/lib/perl5/5.8.8/App/Prove.pm line 475
```

In such cases you must either run `prove` from the parent directory and it will recurse into `t/` automatically, or specify `*.t` while in a `t/` directory.

# Writing Tests #

From here on we discuss how developers should write tests for Maatkit tools and modules.  If you're just testing Maatkit on your server, you can stop reading here.  Thanks for testing with us!

If you've been reading these developer docs in order then you haven't read [Coding Standards](http://code.google.com/p/maatkit/wiki/CodingStandards) or [Coding Conventions](http://code.google.com/p/maatkit/wiki/CodingConventions) yet.  You can skip ahead, read them and come back; else, don't worry about it for now.

**First important thing to know**: as you learned in the [code overview](http://code.google.com/p/maatkit/wiki/CodeOverview), all Maatkit tools are runnable modules, and since the common modules are modules (obviously), that means all our code is testable such that we can generate test coverage using [Devel::Cover](http://search.cpan.org/dist/Devel-Cover/lib/Devel/Cover.pm).

Also important to know (before we get into details) is that all tests...

  * are completely path and working copy independent, relying on the `MAATKIT_WORKING_COPY` env var to achieve this
  * work with Perl prove
  * can be run in random/shuffled order (`prove -s`)
  * use [Test::More](http://search.cpan.org/~mschwern/Test-Simple-0.94/lib/Test/More.pm)
  * use `common/MaatkitTest.pm` for their common testing-related subs
  * use only the Maatkit sandbox servers
  * are in a `t/` directory and in in `.t`
  * should avoid using `BAIL_OUT()` unless truly needed
  * handle the absence of sandbox servers or other requirements
  * pass

I'll say some words on some of these points, then there will be examples and Kool-Aid near the end.

Tests are something (imho) that most people aren't excited to setup and run--they just want to use the tools and have them work.  For those who do test, we really want to make it as easiest and reliable as possible.  Path-independence, working with prove (a well-known script), and order-independence make testing easier and more reliable.

MaatkitTest.pm is the place to put any testing helper subs.  This allows the test scripts to contain only their tests and not extra helper subs.  It's also more efficient to, for example, update `no_diff()` in one place than in 20.  You should familiarize yourself with the module.  It is responsible for exporting `$trunk` which all tests use.

(Historical side-note: `$trunk` should really be called `$working_copy`.  Before we began using branches, all development committed to trunk, but now we commit to trunk and branches so "working copy" is more accurate.  `$trunk` is too widely used so it will be phased out slowly over time.)

Did you know that `BAIL_OUT()` causes the entire test process to die, not just the current test file?  Only use `BAIL_OUT()` for errors that truly mean that all other tests have no chance of working.  At present, a lot of common module tests use `BAIL_OUT()`; this needs to be fixed.

There were times when we had "acceptable failures."  Sorry, you missed those times.  These days, every single test must pass without exception.  This doesn't mean you can't skip tests if, for example, they require MySQL 5.1 and you're running 5.0, but when you do run 5.1 they should begin to pass, too.

Now let's look at some specifics.

## Coverage ##

It does little good if 100 tests cover only 10% of the code.  So we use [Devel::Cover](http://search.cpan.org/dist/Devel-Cover/lib/Devel/Cover.pm) to measure test coverage for both modules and tools.  For modules this works very well; for tools it's a very detailed, ongoing project (I'll explain in a second).

Test coverage files are in `coverage/`.  There's a file for each tool and a file called `summary` that summarizes all the tools' coverage.  Modules have the same structure but in `coverage/common/`.  These coverage files are made automatically by using the script `maatkit/test-coverage` like this:

```
$ maatkit/test-coverage mk-error-log
./101_analyses.......ok                                                      
./102_since_until....ok                                                      
All tests successful.
Files=2, Tests=14,  7 wallclock secs ( 6.16 cusr +  0.40 csys =  6.56 CPU)
Wrote coverage to /home/daniel/dev/maatkit/coverage/mk-error-log
Wrote summary to /home/daniel/dev/maatkit/coverage/summary

$ maatkit/test-coverage OptionParser
OptionParser....ok                                                           
All tests successful.
Files=1, Tests=142,  5 wallclock secs ( 4.18 cusr +  0.06 csys =  4.24 CPU)
Wrote coverage to /home/daniel/dev/maatkit/coverage/common/OptionParser.pm
Wrote summary to /home/daniel/dev/maatkit/coverage/common/summary
```

Notice that `test-coverage` is path-independent, too ("Thank you Daniel for making my life so easy!"  You're welcome.)  As you can see the script takes either a tool name or module name (without `.pm`) and it does all the rest.  Then you can commit the changes in `coverage/`.  This allows us to track the evolution of test coverage which should increase (ideally).

This magic is brought to you in part by the fact that all the code is a runnable module.  In the next section we see why this matters.

## Runnable Module Magic ##

Runnable modules allow us to generate test coverage for the simple reason that running a tool in a test by doing `` $output = `mk-query-digest slow.log` `` runs mk-query-digest external to the test file itself which Devel::Cover can't see because it is only able to hook into the test script and whatever packages the test script uses.  Since each tool functions as a module the tests can `require "<tool>"` and then Devel::Cover can see inside the tool.

Furthermore, this persuades us to write the tools like we write modules: granularly, making use of subroutines.  Admittedly, most tools are not yet (re)written this way so most often we simply run like `$output = <tool>::main()` which is equivalent to `` $output = `<tool>` ``.  We still get test coverage this way.

## Test::More plan skip\_all vs. die() vs. BAIL\_OUT() ##

I presume you're familiar with [Test::More](http://search.cpan.org/~mschwern/Test-Simple-0.94/lib/Test/More.pm).  Its `plan` function is important to us because sometimes we don't know the plan until we checked a few things.  Here's a classic example:

```
if ( !$dbh ) {
   plan skip_all => 'Cannot connect to MySQL';
}
elsif ( !@{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')} ) {
   plan skip_all => 'sakila db not loaded';
}
else {
   plan tests => 19;
}
```

You'll see that construct in a lot of test scripts.  The idea is this:

  * Skip tests if something is unavailable (a sandbox server, a database, etc.)
  * `die()` on errors
  * `BAIL_OUT()` when all hope is certainly lost

One might argue that we should just `die()` instead of `plan skip_all` because the master sandbox server really should be online.  The end result is the same: no tests are ran.  The difference is that we lose the ability to discern real tool errors from what might only be a temporarily offline test environment.  A real tool error is something like trying to load a sample file that doesn't exist.  Whereas the test environment might come back online between now and the next test, chances are a missing sample file is not going to spontaneously appear and it signals a typo.  `BAIL_OUT()`, as mentioned earlier, should only be used in cases when we're certain that the whole test process is doomed to failure.

## Example Tests ##

Now that you know the core principles and reasons for various facets of Maatkit testing, here are some examples to pull it all together.

```
#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 9;

use MaatkitTest;
require "$trunk/mk-error-log/mk-error-log";

# #############################################################################
# Basic input-output diffs to make sure that the analyses are correct.
# #############################################################################

my $sample = "$trunk/common/t/samples/";

ok(
   no_diff(
      sub { mk_error_log::main($sample.'errlog001.txt') },
      "mk-error-log/t/samples/errlog001-report.txt",
      trf => 'sort'
   ),
   'Analysis for errlog001.txt'
);

...
```

This is a classic test script.  The BEGIN block is universal.  It checks for the all-important `MAATKIT_WORKING_COPY` environment variable and pushes that directory to `@INC` so that we can simply `use MaatkitTest;` from anywhere which then automatically exports the all-important `$trunk` variable.

This is an offline test--no sandbox servers needed--so we just `tests => N;`, no need for a delayed `plan`.

We like to put global/common vars near the start.  Unlike the tools and modules themselves, global vars are ok.  A far looser coding standard applies to test scripts.  These globals are usually just to make the tests shorter, so `$sample.'file.txt'` instead of `$trunk/common/t/samples/file.txt`.

`no_diff()` comes from `MaatkitTest`.  You should be familiar with all subs in this common module; they are all exported automatically so no need to `MaatkitTest->import` anything.

Here's another sample.  The first first lines are the same until `use Test::More`:

```
use Test::More;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-parallel-dump/mk-parallel-dump";

my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to MySQL';
}
elsif ( !@{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')} ) {
   plan skip_all => 'sakila db not loaded';
}
else {
   plan tests => 19;
}

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf --no-gzip ";
```

This is a classic online test that requires not only the master sandbox server but that the sakila database be loaded, too (it should be).  Notice the delayed `plan` (in the if-elsif-else branch) and just before that three standard lines that make a Sandbox object.  The Sandbox module is suppose to be a helper module for dealing with the sandboxes.  Its not consistently used and may either be replaced or changed in the future.  For now, it's worth getting to know.

The last two lines show us that these tests run mk-parallel-dump externally, so no test coverage is going to be generated.  For brevity and consistency many scripts do something like `my $cmd = "$trunk/<tool>/<tool> -F $cnf ..."`.  Specifying `-F` is helpful otherwise DSNs will need to be full like `h=127.1,P=12345,u=msandbox,p=msandbox` instead of taking most defaults from that defaults file.

For more examples just look at what's already there!  Newer scripts tend to make better examples since we're still in the very long processes of updating old tests created before we had "everything" figured out.

## Test File Naming ##

Module test files are the same name with a `.t` extension.  Tools may or may not have modularized test files.  For example, mk-find has only `t/mk-find.t`.  But most tools have modularized test files, like:

```
$ ls -1 mk-parallel-dump/t/
001_chunk_tables.t
101_dump_sakila.t
102_filters.t
103_standard_options.t
104_gzip.t
105_resume.t
106_progress.t
107_locking.t
201_issue_223.t
202_issue_275.t
```

This is the preferred method for tools.  Although the tests are usually ran in random/shuffled order, there's a convention for the leading number:

  * 001-099: subroutines in the tool's package
  * 101-199: features, options
  * 201-299: issues

Most tools' test scripts fall in the second range.  There's no hard and fast rule for whether an issue should get a 200 test file or put be into an existing 100 test file for the feature or option that the issue addresses.  For example, if we changed something about `--resume`, although there would be an issue for it, I would put it in `105_resume.t` since it will become the norm for that option.  But if `--resume` caused a crash under some conditions, I would put that in a separate 200 file.

# Next Steps #

If all you're doing is testing Maatkit on your server, you can stop reading here.  Thanks for testing with us!

If you're planning to [fix bugs](http://code.google.com/p/maatkit/wiki/FixingBugs), please continue reading the [Branch Management](http://code.google.com/p/maatkit/wiki/BranchManagement).