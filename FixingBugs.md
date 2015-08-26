#summary Fixing bugs in Maatkit code

Welcome to the wonderful world of fixing bugs in Maatkit code.  I hope that before reading this guide you read:

  * [Getting Started](http://code.google.com/p/maatkit/wiki/GettingStarted)
  * [Code Overview](http://code.google.com/p/maatkit/wiki/CodeOverview)
  * [Testing](http://code.google.com/p/maatkit/wiki/Testing)
  * [Coding Standards](http://code.google.com/p/maatkit/wiki/CodingStandards)
  * [Coding Conventions](http://code.google.com/p/maatkit/wiki/CodingConventions)

If not, you really should.  This wiki assumes that you are thoroughly versed in all the information presented in those wikis.

This wiki is more fast-paced and terse than those wikis because I figure by now you're eager to get some work done.  So let's begin...

# Isolated vs. Systemic Bugs #

This wiki is about isolated, clearly defined bugs.  Ideally, these are bugs that happen in only one package.  They are the kinds of bugs that cause blatant crashes or blatantly wrong output.  These differ from systemic bugs which are more difficult to track and fix and require an operating knowledge of several packages at once and how these packages interact.  By contrast, isolated packages should require only limited knowledge of one package or even just one subroutine in one package.  It should not be necessary to fix stuff in other packages first before you can fix your primary bug.  If this is not the case and you're dealing with a real systemic, multi-package bug, then read this wiki and continue with the next step listed in the final section.

# Locate the Bug #

Bugs are either in the tool's package (e.g. `package mk_kill;`) or in some module.  They're usually in modules because most tools are mostly modules.  mk-query-digest is 80% module code.

If you already know the line where the bug happens, then simply look around to see what package/module you're in.  If you have debug output, the lines are helpfully prefixed with this information, like:

```
# MemcachedProtocolParser:6542 14907 $cmd is a  replace
# MemcachedProtocolParser:6565 14907 Don't know how to handle replace command
# mk_query_digest:8641 14907 Use of uninitialized value in addition (+) at ./mk-query-digest line 6580, <$fh> line 1.
```

The debug out format is: `package:line PID`.  In this case, the bug is reported in mk-query-digest (`mk_query_digest`) at line 8641.  Small problem, though, because here's that line:

```
eval {
   # Run events through the pipeline.  The first pipeline process
   ...
```

So mk-query-digest is catching a failure in one of its modules.  Obviously the module is MemcachedProtocolParser because that was the last one called before the bug.  There's even has a helpful debug message: "Don't know how to handle replace command".  One guess what's causing this bug?  Yes, the fact that MemcachedProtocolParser doesn't handle memcached replace commands, and that's exactly what the tool got given the first line of the debug output.

So the bug is located: `common/MemcachedProtocolParser.pm`, somewhere around the lines that print that debug statement (this is why we try to make debug statements unique, precise).

Here's a **critical distinction**: line numbers in a tool's debug output are relative to the tool, not its module.  There is no line 6565 in `common/MemcachedProtocolParser.pm`.  That's line 6565 in mk-query-digest.  So you must translate full tool line numbers to individual module line numbers.  Do this by finding the same debug statement in the module.  In this case, mk-query-digest line 6565 equals MemcachedProtocolParser line 282.  These line translations vary wildly for various reasons (stripped comments, revision changes, etc.) so be careful.

# Write a Test #

It should be simple enough to write tests _first_ then fix the bug because you should know what output or end result is correct before fixing the bug.  Here are the steps for writing a test in brief; some steps will be clarified later:

  1. Make sample files that reproduce the bug and copy them to the relevant `t/samples` directory
  1. Write a test that tests for the expected correct output or result
  1. Run the new test and see that it fails (this is loose confirmation that you've reproduced the bug)
  1. Fix the code
  1. Run the test again and see that it passes (confirmation of the bug and your fix)
  1. Reprove surrounding tests

Here are clarification on those steps...

## Sample Files ##

Some tests don't need sample files, some do.  It just depends on the nature of the bug.  Sample files are preferred to hard-coding things in the test scripts.  Almost every `t/` directory has a `samples/` directory under it.  Look at the existing samples for ideas on how things are named or organized.

## Writing the Test ##

Two things to note here.  First, if you're fixing a module, append your new test to the end of the modules's test file in `common/t`.  The preferred method is to put bug tests at the end with a header like:

```
# #############################################################################
# Issue 804: mk-table-sync: can't nibble because index name isn't lower case?
# #############################################################################
```

If you're fixing a tool, then either append your new test to the end of an existing test file which seems to relate to the bug or create a new test file in the 200-series of bug-related tool tests.  See the end of [Testing](http://code.google.com/p/maatkit/wiki/Testing) for information on the name convention of modularized tests.  Most tools have modularized tests.

For example, if you're fixing a bug related to mk-query-digest --run-time, append it to `116_run_time.t`.  All --run-time related tests should go in this file.  Or, if you feel that the bug is sufficiently unique enough, you could create `206_issue_N.t`, the next 200-series test file at the time of this writing.  There's no hard and fast rule about what to do here; look at the other test files and use your best judgment.

The second thing to note, on a completely different subject: in some cases, the correct output for a bug may be too complex to know and you can fudge the process.  For example, in fixing the MemcachedProtocolParser above I knew that the output would be an event with `cmd => 'replace'` and no error message or crash.  I didn't bother to convert the hex dump manually to know the exact values of the event.  Instead, I wrote a test that expected zero events.  I ran it (before touching the code) and it died instead with the error message.  Then I fixed the code and the test started saying, "Expected zero events but got this event", without error messages or crashes.  The event's value looked normal and it was `cmd => 'replace'` so I copied that into the test and re-ran it and it passed as expected.  (In this case I employed a Perl virtue: laziness.)

My experience has been that I don't know how to write a test first when either 1) I simply don't know what the correct output is, or 2) I don't understand the nature of the bug thoroughly enough.  In the first case, I use other tools or methods to educate myself about what I should expect.  In the second case, I dig more deeply into the nature of the bug, using the Perl debugger if necessary.

Remember: we're talking about isolated bugs in this wiki, so they should be relatively precise enough to test easily.

## Reprove Surrounding Tests ##

If you fixed a module, prove all modules (`prove -s trunk/common/t`).  Many modules are interdependent so you can fix one module and break another.  If you fixed a tool, prove the tool (`prove -rs trunk/tool`).  Some tools are slightly interdependent too, notably mk-parallel-dump and mk-parallel-restore and mk-table-checksum and mk-table-sync.  If you're paranoid, just prove the entire Maatkit test suite (`prove -rs trunk/`).

# Commit #

Once you've isolated the bug, wrote a test that failed, fixed the code, re-ran the test and now it passes you're ready to commit.  If you added sample files you'll need to `svn add` them.  Before commit, you might want to `svn status` to make sure everything is ok and that your commit will only commit what you want.

When you commit, remember the GC issues and revisions [conventions](http://code.google.com/p/maatkit/wiki/CodingConventions).

Congratulations and thank you for your bug fix!  If you want someone to review your work, just ask and we'll be happy to do so.  We'll probably do so even without you asking just as a quality-control measure.  Code reviews are quite helpful.

# Update the Tool #

You may or may not want to do this step.  If you fixed a tool, you've already updated it when you committed it, but if you've fixed a module that module still needs to be updated in the tool and then the tool reproved and committed.  Normally me and Baron will do this, but if you want to, contact us and we'll tell you how, or follow the next step mentioned in the next section...

# Next Steps #

A lot of good can be accomplish with just the information presented thus far.  But if good isn't good enough for you, you can proceed to [Enhancing Tools](http://code.google.com/p/maatkit/wiki/EnhancingTools) which touches upon topics like systemic bugs and implementing new features.  Manically exciting stuff!