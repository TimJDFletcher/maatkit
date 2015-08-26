These coding conventions pickup where the [coding standards](http://code.google.com/p/maatkit/wiki/CodingStandards) left off.  The standards say how the code should be formatted and the conventions provide a guide for how that well-formatted code should be employed.  Also covered are conventions related to the community and Google Code issues and revisions.

This wiki is not an attempt to tell you how to program, only an attempt to document some principles that we try to follow that make the code more elegant or make all our lives easier.

You should have read [the dog book](http://oreilly.com/catalog/9780596001735/) by now.

# Community #

Almost nothing about Maatkit development is done behind closed doors.  Involving the community is fundamental.  Major projects should start with an email to the mailing list. It's best if minor projects do too. Ask opinions, explain your thoughts and plans, and seek feedback and contribution.

Google Code is a liaison between developers and the community; it's where nearly all our work and discussion happens.  (We discuss some in #maatkit on Freenode IRC.)  So make issues for everything and reference them appropriately...

# Issues and Revisions #

First the easy material: working with Google Code (GC) issues and revisions.  As a developer, the issues you create should be thorough and reproducible if possible.  You don't have to repeat what's already been said, but please make reference to the appropriate material, especially related issues or revisions.

Putting "issue N", where N is an issue number, into any comment (issue or revision) will cause GC to make that text a link to that issue.  The same is true for "rN" where N is a revision number.  Please always do this, especially when you submit a code fix for an issue.  A good example:

Issue: http://code.google.com/p/maatkit/issues/detail?id=818
Submitted fix (references issue): http://code.google.com/p/maatkit/source/detail?r=5535

The submitted fix mentions the issue and the issue, after being fixed, references the submitted fix revision.  Google Code's issue tracker [accepts a syntax in Subversion commit messages that can update any aspect of an issue](http://code.google.com/p/support/wiki/IssueTracker#Integration_with_version_control).  Feel free to use this liberally.

Revision comments should be short but as descriptive as possible.  We prefer something like "Handle memc cmd replace" to just "Fixes [issue 818](https://code.google.com/p/maatkit/issues/detail?id=818)".  If you're unsure, look through past submissions by Daniel or Baron for ideas on what seems normal (or lazy).

Try to produce easily diffable code as best as you can.  Google Code's color diff is pretty smart, but some things, like moving whole blocks of text, make diffing difficult.  Sometimes this cannot be avoided, but it's worth trying for.  Sometimes it makes all the difference when tracking down a weird bug that crept in months ago without anyone or any test noticing.

Issues are generally not the best place to discuss new stuff/ideas/approaches.  That's what the [discussion list](http://groups.google.com/group/maatkit-discuss) is for.  An issue is mostly used for back-and-forth with the reporter, asking them to clarify stuff, provide a sample, getting feedback from them, etc.

## Labels and Tags ##

Please use the issue labels accordingly.  Make sure the Tool label is always set and that real bugs or defects are labeled as such not Enhancement or vice-versa.  Set yourself as the Owner.  You do not need to Cc other developers; they get emails about everything that happens on the project.  When done, set the status to Fixed.  We don't really use the Verified status label yet.  If you want someone to review your fix, ask.  We also don't use GC's "code review" feature because it requires branches and we don't use branches.

There are a few other labels that have special meaning and functionality:

  * Tag is for arbitrary tagging of issues, such as Tag-replication or Tag-usability or Tag-whatever.  Try to look at other related issues to see what tags they use; using the same tags makes it easy to cross-reference issues.
  * Module lets you blame an issue on a specific module in the common/ subdirectory.  The idea is that when I'm fixing some issue and getting myself familiar with the code, it might be good to look at other things we want to change about that code at the same time.  Best to do while the tests and functionality are fresh in mind.  So, for example, Module-QueryRewriter.pm.

When in doubt, look at issues handled by Daniel or Baron or ask.  None of this is critical stuff; it's just housekeeping.

# Coding #

Over the years we've amassed some unspoke conventions, how things are done "the Maatkit way."  In no particular order, here's a blast of ideas, principles, examples, etc.  Some of them are cryptic; you can ask Daniel to clarify.

  * Write testable code
  * Test your code
  * Never assume that a var can't be undef--oh yes it can!  Do `($var || '')` or `($var || 0)` or something equally defensive
  * Baron's maxim: "Perfect is the enemy of good."
  * Ryan's maxim: "Always assume the environment that your program will run in will be in a constant state of failure."
  * [Josh's Rules (of Database Contracting)](http://it.toolbox.com/blogs/database-soup/joshs-rules-of-database-contracting-17253)
  * map and grep are your friends
  * Favor named subroutine arguments: `foo(host => 'localhost', port => 12345));`--see below
  * Pass in a list, return a list: @new\_vals = bar(@old\_vals)
  * Don't modify arguments in a sub; e.g. in previous example don't modify @old\_vals in bar(), return a list of the new, modified values
  * Don't reinvent the wheel; ok: `$i += $_ for @vals;`, but better: `use List::Util qw(sum);  $i = sum(@val);`  (on two lines of course)
  * If it looks too exotic, e.g. `$#{@$array};`, it may be unreliable across Perl version (written: `$n = scalar(@$array) - 1;`)
  * Use `open my $fh, '<', $file` instead of barewords like `open FH, "< $file"`
  * Avoid global vars at all cost
  * Avoid local (dynamically scoped) vars unless you have good reason
  * When writing modules, make them object-oriented; use accessor methods and such (even though Perl OO is loosely OO)
  * Be granular: huge subs (include a huge main()) are more difficult to test
  * Identify what blocks of code are doing, make those blocks do just that (easier to test/refactor/deocmpose)
  * Avoid nested loops
  * Use iterators where possible
  * Do work in "chunks", or "units of work".  Streaming these chunks is good; building a big list of things to do before actually doing it is less ideal.
  * Be aware where code may die and try to catch these deaths elegantly so the tool doesn't simply drop dead and leave the user wondering what happened
  * Use descriptive errors.  The user may not know what it means but "Failed to open file" doesn't even help the developer much.
  * Avoid dynamically created anonymous subroutines evaled into existence at run-time; use closures instead
  * Use MKDEBUG frequently but not with reckless abandon; the debug output is already huge
  * When using MKDEBUG always think to yourself: "If all I'm giving is the debug output can I both reproduce and fix the problem?"  The answer should be "yes".
  * Favor encapsulating sets of common tasks in modules; they're easier and quicker to test
  * Avoid double-negatives, e.g. `$no_foo = 0` (no no foo?), do instead: `$have_foo = 0`
  * Know thy [Operator Precedence and Associativity](http://perldoc.perl.org/perlop.html#Operator-Precedence-and-Associativity) and make sexy, elegant use of it
  * Even one line of documentation is helpful--say something!
  * If you feel there's a better, more elegant way, there probably is
  * You rarely see your own bugs; had you been able to see them in the first place, you would have fixed the code before someone else noticed
  * People read the POD/documentation, so make it good and thorough
  * If people don't read the POD/documentation and it would have answered their question, well then we know who to blame
  * No one's memory is perfect; document stuff, create issues, record your thoughts somehow/somewhere because you can forget your own reasons for coding something
  * We've not found a reason yet to use scalar refs like `$$foo`
  * Write extensible code.  Chances are it will be extended.
  * A consistent, documented interface can make up for it being less than ideal

# Testing #

  * You don't know anything about the reliability of code until tests have proven it
  * Tests should be paranoid
  * Every failure is significant; never give up on finding out why the failure is happening
  * Never change a test unless you can provide incontrovertible proof for why the current output is correct and the test is wrong
  * Tests should be fiercely independent: independent of path (cwd), of state of database, etc.--anything they need they should make happen and verify that it has happened (e.g. wipe db clean)
  * Testing screen output (i.e. capturing STDOUT) is ok but not ideal
  * Testing debug output is bad
  * Forks and pipes and shell-outs are problematic (that means you, awk and sed!)
  * Even powerful machines can be slow at times; don't assume 1s is long enough for something to happen (use `MaatkitTest::wait_until()` or `wait_for()`)
  * Nobody ever complained that tests were too thorough
  * If code can't be tested, rewrite the code
  * Tests that depend on the actual passage of time are tricky and not ideal

# Named Subroutine Arguments #

You'll see this frequently:

```
sub foo {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(host port) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
```

That code checks for the required named args, `host` and `port` in this case.  General argument names should be sensibly named.  Args for modules should be named the same as the module, so `$arg{DSNParser}` to pass a `DSNParser` object--this is the new convention at least.  At present there's a lot of code that uses common module abbreviations (listed next).

If the sub takes just one or maybe two or three "obvious" or "intuitive" arguments, maybe you don't have to use named args.  Use your best judgment.

# Module Abbreviations #

| **Scalar** | **Common Module** |
|:-----------|:------------------|
| apl        | AggregateProcesslist |
| dk         | DuplicateKeyChecker |
| dp         | DSNParser         |
| du         | MySQLDump         |
| ea         | EventAggregator   |
| fi         | FileIterator      |
| lp         | LogParser         |
| ls         | LogSplitter       |
| ma         | MySQLAdvisor      |
| mi         | MySQLInstance     |
| o          | OptionParser      |
| pl         | Processlist       |
| qp         | QueryParser       |
| qr         | QueryRewriter     |
| qv         | QueryReview       |
| q          | Quoter            |
| sb         | Sandbox           |
| sm         | SQLMetrics        |
| tp         | TableParser       |
| vp         | VersionParser     |

# Next Steps #

If you've read all the devel docu up to this point, congratulations!  I know it's a lot.  But with all that in mind, you're ready for action: [Fixing Bugs](http://code.google.com/p/maatkit/wiki/FixingBugs) and beyond.