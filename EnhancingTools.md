#summary Adding new features and fixing complex bugs in Maatkit code

This wiki is for the advanced developer who has surely read and mastered:

  * [Getting Started](http://code.google.com/p/maatkit/wiki/GettingStarted)
  * [Code Overview](http://code.google.com/p/maatkit/wiki/CodeOverview)
  * [Testing](http://code.google.com/p/maatkit/wiki/Testing)
  * [Coding Standards](http://code.google.com/p/maatkit/wiki/CodingStandards)
  * [Coding Conventions](http://code.google.com/p/maatkit/wiki/CodingConventions)
  * [Fixing Bugs](http://code.google.com/p/maatkit/wiki/FixingBugs)
  * [Documenting Code](DocumentingCode.md)

Here we discuss how to add new features, alter existing features, implement code enhancement, and fix complex, systemic bugs.  These topics are related because all require a relatively deep knowledge of many aspects of Maatkit code at once.  There is no step-by-step guide for doing any work at this level; this wiki is meant to enlighten your efforts so they can be fruitful as quickly and easily as possible.

A quick point of clarification: a "feature" is something that the user can see, use, affect and an "enhancement" is not directly perceivable or controllable by the user.  The two are closely related; enhancements don't require a tie-in to the tool whereas features do.

# Adding New Features #

There are three primary concerns when adding a new feature: location, implementation, and tie-in.  There are several locations where a feature can be implemented.  Once implemented there, you have to tie the feature into the tool so the user can make use of it; this usually involves common modules like OptionParser.

## Location ##

Like fixing bugs one has to ask their self: where is this feature going to be located (i.e. implemented)?  That depends on the nature of the feature and what it does.  Features implemented primarily in modules usually require extra code in the tool to tie the user to the feature via some method like a new command line option.  But sometimes a feature is implemented primarily in the tool's package which makes uses of existing modules.  So there's no cut and dry answer to this question, but here are four general scenarios.

### Additional Feature ###

An additional feature is one that is like or related to existing features.  It's not a totally new concept so there's probably already a module that embodies its nature and work.  The additional feature should be implemented in that module and then extra code implemented in the tool to make use of the new feature.

For example, anything to do with splitting logs is implemented in LogSplitter (`common/LogSplitter.pm`).

Simply look at all the common modules and use their names to get an idea of what work they encapsulate.  At this level you should be at least vaguely familiar with all the modules.

As a counter example, there is no module for additional features related to --since, which is an option in more than one.  Why is this?  Maybe because --since operates differently in the different tools, or maybe we just never thought to make a common module for it.  Maybe there should be a Since module, but there's not, so any such related features would be "new features", explained in the next section.

As a strange example, there are modules that are only used by one tool for one thing, like QueryReportFormatter (used in mk-query-digest).  Why is this a module and not a collection of subroutines in mk-query-digest?  I don't know.

So the point is: additional features are similar to other features and thereby get implemented in the module that handles those other features.

### (Truly) New Feature ###

A (truly) new feature is one that's unlike other features and has no module.  The question here is: should a module be created that implements the feature's work or should it be implemented in the tool's package?  If the feature is sufficiently complex enough then a module should be created and then added to and tied into the tool.  Or if you think that the feature will be reused by more than one tool then it should be implemented in a module.  LogSplitter is an example former; SchemaIterator is an example of the latter.  After the module is created, it becomes the home for additional, related features.  So (truly) new features expand the realm of potential additional features.

Conversely, if the feature doesn't warrant and module and gets implemented directly in the tool's package, then it's a "tool feature", explained in the next section.

### Tool Feature ###

A tool feature is one that is implemented in one tool's package and does its work in that package whatever else is already available.  An example is mk-query-digest --print which effects certain things just inside `package mk_query_digest` (specifically, it causes a pipeline process to be created and added to the pipeline).  These features may use modules but their work is done in the tool's package.

### Systemic Feature ###

A systemic feature effects or interacts with multi-packages.  Its work is not localized in one place.  These features are usually common options/switches/controls for various packages.  --dry-run is a systemic feature because it has effects in a tool's package and several modules.  These features are the most difficult to implement and require testing in several places.

## Implementation ##

Implementeing additional and (truly) new features is easy: the code is implemented in the appropriate module.  I can't tell you how to write this code, but there are 70+ examples in `common/`.  :-)  LogSplitter and SlavePrefetch are good examples.

Modules are meant to stand alone so you don't need to know all Maatkit code to write your own module or extend an existing.  That's not to say that some modules don't use other modules.  TableParser is used by several other modules, as is Quoter.  As I said before: at this level you should be at least vaguely familiar with all the modules.  So if you need to use Quoter in your module, you'll have to learn how to use Quoter.  There 20+ examples of module usage: all the tools.

As the [convention](http://code.google.com/p/maatkit/wiki/CodingConventions) says, we favor OO-like modules, so if the module expose a nice interface it will be easy to tie it into the tool.

Testing is, of course, obligatory.  Any new feature must be tested.  When implemented in a module this is usually pretty easy; it's similar to testing a bug fix.

If it's a tool feature, then implementation happens in the tool's package and is tested in the tool's test suite.  The same considerations about whether to use an existing test file or create a new one that were considered when [fixing bugs](http://code.google.com/p/maatkit/wiki/FixingBugs) applies.  In general, if the feature does substantial, non-trivial work, it should be implemented in a new subroutine.  Try not to make `main()` any larger.  Subroutines are more easily testable.

If it's a systemic feature, you'll want to talk to me or Baron or propose the feature on the [discussion list](http://groups.google.com/group/maatkit-discuss).

## Tie-in ##

After locating and implementing the feature, you probably need to provide the user a way to invoke or control the feature.  Most often this means a new command line.  After all, what good is a new feature that is hidden from the user?

OptionParser makes tying features to user command line options very easy.  OptionParser, in brief, reads the tool's specially formatted POD and automatically generates the available command line options from it.  For the moment, you can read how OptionParser work at this wiki: http://code.google.com/p/maatkit/wiki/OptionParserInternals.  Eventually, this information will be put in OptionParser.pm.

Use any tool's POD as a guide for how to format the OPTIONS section of the POD.  Then simply add a command line option for your new feature accordingly.  Once added, the standard `$o` object in every tool allow you to access that (and all) options, like `$o->get('your-new-feature')`.  The OptionParser interface is quite simple:

```
   my $o  = new OptionParser(
      strict      => 0,
      prompt      => '[OPTION...] FILE [FILE...]',
      description => q{parses and aggregates MySQL error log statements.},
   );
   $o->get_specs();
   $o->get_opts();

   $o->save_error('some error msg') if ...;

   $o->usage_or_errors();

   $o->get('foo');               # get value for --foo
   $o->got('foo');               # true if --foo was explicitly giving on the cmd line
   $o->set('foo', [qw(a b c)]);  # set --foo to that arrayref (or any scalar val)
```

Therefore the final tie-in is usually something as simple as:

```
my $val = $o->get('my-new-feature');

print "Hooray!" if $o->get('that-new-feature');
```

If you implemented the feature's code correctly (of course you did because you tested it first!) then you're done.

# Altering Existing Features #

Altering an existing feature is essentially the same as fixing a bug because the existing code is doing one thing and you want it to do another.  The primary difference is: **existing features should rarely be altered** (unless you've branched Maatkit and are working on your own distro).  If you know how to fix a bug (and you should by now) then you know how to alter a feature; all you really need to do is talk it over with me, Baron and the [discussion list](http://groups.google.com/group/maatkit-discuss).

Some features are nearly unalterable, like the [standardized command line options](http://code.google.com/p/maatkit/wiki/CommandLineOptions).  So in the inverse case you may need to alter a feature only if you find that it's _supposed_ to be working one way but in fact it's not (which, again, is just like fixing a bug).

# Code Enhancements #

Code enhancements are very frequent tasks.  They, too, are like bugs in how you should go about implementing them.  The primary difference is that the code and tests are already correct, we just want to tweak how the code works.  This often happens when we refactor or decompose code.

Performance optimization is another case in which enhancements are made.  For example, mk-query-digest is profiled (only by Baron for various technical reasons) and improved for speed where possible (and checked that we don't lose speed after other enhancements or new features).

**Key thing to remember**: code enhancements should generally not cause tests to fail unless it's expected ahead of time that tests will fail.  This is the one and only rare case in which we undermine the tests.  For example, enhancements to mk-query-digest's output frequently cause tests, which check the literal format of that output, to fail.  Whenever we do such enhancements we scrutinize the diffs (GC's color diffs) to make sure that only the formatting changed, not the values.  Be careful when doing this!  Remember the testing-related [Coding Conventions](http://code.google.com/p/maatkit/wiki/CodingConventions)!

Otherwise, not much else can be said about enhancements.  Presumably, you already know where and what you want to enhance, so go do it and be mindful of the tests.

# Fixing Complex, Systemic Bugs #

I saved this topic for last because, in my opinion, it's the most challenging work.  The very nature of such bugs means that you will need a firm grasp of all relevant Maatkit code which doing all the aforementioned usually provides.  That is, if you can fix isolated bugs and implement features or code enhancements, then you're fully equipped to eradicate complex, systemic bugs.  I make these suggestions for your effort:

  * Be able to reliably reproduce the bug, which usually means having a sample file
  * Reduce sample files as much as possible while still being able to reproduce the bug
  * Study MKDEBUG output carefully
  * Know how to use the Perl debugger well
  * Don't underestimate [ripple effects](http://hackmysql.com/blog/2009/11/18/debugging-and-ripple-effects/)
  * Look to other related sources of information, like the general log or strace
  * There is always an answer; this is computer science, not computer voodoo

# Next Steps #

We're almost finished.  Ahead is:

  * [Assembling Tools](http://code.google.com/p/maatkit/wiki/AssemblingTools)
  * [Release Instructions](http://code.google.com/p/maatkit/wiki/ReleaseInstructions)
  * [Developer Utilities](http://code.google.com/p/maatkit/wiki/DeveloperUtilities)