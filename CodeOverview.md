#summary A high-level overview of Maatkit code and its organization

Maatkit is comprised of 20+ tool, 70+ modules, 30+ utility scripts, and over 2,500 tests.  There's over 24,700 lines of module code alone.  But don't worry!  It's actually easy to get your mind around it all because it's all well organized.

This wiki looks at how the code is organized, both in the file structure of the svn trunk and inside the tools.  Knowing this organization is very important for focusing your development efforts.

First we'll look at the directory structure of the svn trunk.  Then we'll look at how all these files come together to form the actual tools like mk-query-digest.

# Trunk Directory Structure #

A fresh code checkout from trunk (see [Getting Started](http://code.google.com/p/maatkit/wiki/GettingStarted)) looks like:

```
common/
   t/
      samples/
coverage/
doc/
maatkit/
mk-archiver/
   t/
      samples/
mk-deadlock-logger/
mk-duplicate-key-checker/
... other tools directories like mk-query-digest/, mk-parallel-dump/, etc. ...
mk-visual-explain/
sandbox/
   sakila-db/
   servers/
      5.1/
   server-scripts/
skeleton/
spec/
udf/
util/
   t/
      samples/
```

Not all directories are shown.  For example, every tool's dir (`trunk/mk-*`) should have a `t/` and probably a `t/samples` dir.

All these directories are relative to "trunk".  Trunk varies depending on how you checked out the code.  Usually trunk is `maatkit` or `maatkit-readonly`.  The full trunk path on my box is `/home/daniel/dev/maatkit/trunk`.  So `common` is really `/home/daniel/dev/maatkit/trunk/common`.

For simplicity at the moment, we deal with just trunk, but really what we're dealing with is any working copy of the code, which can be either trunk or some branch as explained below and in the [Testing](http://code.google.com/p/maatkit/wiki/Testing) wiki.

Here's a synopsis of all the important directories:

| **Directory** | **Contains** |
|:--------------|:-------------|
| common        | All common modules, explained in the next section |
| `*`/t         | Tests for code in the parent directory; e.g. `common/t` has tests for the common modules in `common` and `mk-kill/t` has tests for code in `mk-kill` |
| mk-`*`        | Each tool has its own dir, so mk-query-digest is in dir `mk-query-digest`.  All released tools start with `mk-` so `mk-*` refers to them all. |
| coverage      | Text files that show test coverage for tools and common modules |
| maatkit       | Various scripts and files used to do releases, explained in the [Developer Utilities](http://code.google.com/p/maatkit/wiki/DeveloperUtilities) wiki (not to be confused with `util` below) |
| sandbox       | Files related to the Maakit test environment, explained in the [Testing](http://code.google.com/p/maatkit/wiki/Testing) wiki |
| udf           | C code for the FNV\_64 UDF |
| util          | Various unreleased tools, scarcely documented |

So in one sentence that probably covers the focus of 90% of development: common modules in `common`, tools in their own respectively named directories, and tests under `t`.

## Branches and Other Directories ##

A lot of development work is done directly on trunk, but branches of trunk are also used.  And snapshots of trunk are taken at each release and copied to the releases directory.  The whole svn repository from its root looks like:

```
branches/
   mk-variable-advisor/
releases/
   2010-07/
trunk/
```

Instead of checking out trunk, you can checkout a branch which is a full, independent copy of trunk (until it's merged back into trunk).  Whether you work on trunk or some branch affects [Testing](http://code.google.com/p/maatkit/wiki/Testing), as explained in that wiki.

The releases should never be modified.  They're created once by the person who does the release.  They can be checked out if you want to tinker with old code, but please do not commit anything to releases.

# Code Organization #

Code inside each tool has a standard layout:

  1. Shebang line (`#!/usr/bin/env perl`)
  1. Legal/GNU license/copyright stuff
  1. Common modules
  1. `package <tool>` where `<tool>` is the tool's name with `-` replaced with `_`
    1. `sub main`
    1. Subroutines
    1. Run the program `if ( !caller ) { exit main(@ARGV); }`
  1. POD (Documentation)

The first two aren't interesting, the rest are, so let's look at them in turn.

## Common Modules ##

Maatkit tools are fundamentally a collection of common modules glued together and set to work by the tool's package (explained in the next section).  As you probably already know, most modules are used in a tool by doing like `use Foo;` to use the Foo module.  For technical reasons we don't do this with our common modules.  Instead, we copy every module that a tool uses from `common` into the tool's code.  So mk-query-digest has copies of `common/DSNParser.pm`, `commmon/OptionParser.pm`, etc.  (Scripts in `maatkit` help us keep these module copies up to date.)  Consequently, mk-query-digest does not have to `use DSNParser` because `DSNParser` is "local" (I use that term loosely; I know it has other connotations in Perl programming).  The tools only `use` core or common (i.e. non-Maatkit) modules; these are the modules listed at [Getting Started](http://code.google.com/p/maatkit/wiki/GettingStarted).

So usually the first few hundreds or thousands of line of code of a tool are just copies of common modules.  The code for the tool itself is nearer the bottom of the tool; it begins with `package <tool>` where `<tool>` is the tool's name with `-` replaced with `_`.  This is explained in the next section.

Important to know: comments in common modules are removed when they are copied into tools.  The only way to see these comments is via code checkout from trunk.

## The Tool's Package ##

Here's a real-life example from my-query-digest:

```
# ###########################################################################
# This is a combination of modules and programs in one -- a runnable module.
# http://www.perl.com/pub/a/2006/07/13/lightning-articles.html?page=last
# Or, look it up in the Camel book on pages 642 and 643 in the 3rd edition.
#
# Check at the end of this package for the call to main() which actually runs
# the program.
# ###########################################################################
package mk_query_digest;
```

The code for mk-query-digest itself begins here (around line 10795).  Everything above is copies of common modules.  Everything below until the POD is mk-query-digest.

As that comment block explains, the tools are runnable modules.  This allows us to do test coverage more easily.  From the user's perspective this means nothing.  From the developer's perspective it means that the tools do not use Perl's implicit `package main`.  Instead every tool uses `package <tool>`.  Since `-` are illegal characters in package names, they're changed to `_` in the code.

`sub main` is analogous to `package main`.  `main()` is called due to these lines just before the tool's package ends and POD begins:

```
# ############################################################################
# Run the program.
# ############################################################################
if ( !caller ) { exit main(@ARGV); }

1; # Because this is a module as well as a script.
```

If you don't understand how this works, that's ok.  You'll learn it when it's necessary to do so.  :-)

### Subroutines ###

Where `main()` ends and the tool's subroutines begin is clearly marked:

```
# ############################################################################
# Subroutines.
# ############################################################################
```

Some tools have a big `main()` and few subs, others have a small `main()` and lots of subs.  A smaller `main()` and more subroutines is preferred because it makes testing easier.

## POD (Documentation) ##

The bottom of every tool is its POD/documentation.  This is what you see when you `perldoc <tool>`.  The standard POD headings/sections are:

  * NAME
  * SYNOPSIS
  * RISKS
  * DESCRIPTION
  * optional: other description-related paragraphs
  * OPTIONS
  * optional: todo/options not yet implemented
  * DOWNLOADING
  * ENVIRONMENT
  * SYSTEM REQUIREMENTS
  * BUGS
  * COPYRIGHT LICENSE AND WARRANTY
  * optional: SEE ALSO
  * AUTHOR
  * optional: acknowledgements, historical side-notes, etc.
  * VERSION

Several scripts in `maatkit` are used to check the tools' PODs.

# Next Steps #

Now that you're familiar with the Maatkit landscape, you won't be lost when finding or fixing bugs.  If this is what you intend to do, you should continue reading:

  * [Testing](http://code.google.com/p/maatkit/wiki/Testing)
  * [Coding Standards](http://code.google.com/p/maatkit/wiki/CodingStandards)
  * [Fixing Bugs](http://code.google.com/p/maatkit/wiki/FixingBugs)