If you're planning to enhance a Maatkit tool by adding or changing code, you'll need to know first how the code is documented.

Maatkit packages and subroutines are documented with [Natural Docs](http://www.naturaldocs.org/) in the `svn/docs` directory (i.e. not in `trunk`).  Natural Docs v1.5 is included in the svn repo, in `naturaldocs/`, so you don't need to install it on your system.  The Natural Docs (a.k.a. nd) config for the Maatkit project is saved in `nd-config/`.  This config should not need to be changed unless a new tool or module is added.  And the actual nd output (pretty, cross-linked HTML pages) is saved in `code/`.

Generating the documentation with nd is automated via the script `maatkit/generate-naturaldocs` (and its helper script `maatkit/extract-tool-package`) in any working copy of the code.  First we'll cover how to write nd-compatible code documentation in the tools and modules, then we'll cover how to generate the nd output with `generate-naturaldocs`.

# Natural Docs Compatible Code Documentation #

Begin by carefully reading the Natural Docs [Documenting Your Code Walkthrough](http://naturaldocs.org/documenting/walkthrough.html).  It's not Perl-specific, but it gives you the basic feel for nd.  Then read all the other nd docs so you're fully versed in nd.  Doing so, you'll come across a section that explain how to write nd documentation for Perl like:

```
=begin nd

Function: Multiply
Multiplies two integers and returns the result.

=cut
```

**Ignore this.**  I discovered that Natural Docs is smart enough to understand Perl hash comments.  So look now at `Quoter.pm` and `mk-table-sync` for complete examples.

Another thing that I didn't see in the nd documentation but found to be the case is that nd uses the first sentence of any description for that item's one-liner description.  Therefore, when you write descriptions, make sure the first sentence is short and to the point.  It can be very general; a curious person will read the full description if it seems to be related to what they're looking for.

Finally, because we're crazy grammarians, notice how the code docu in `Quoter.pm` is expressed:

  * Package descriptions begin with a complete sentence describing what the package/module does, like "Quoter handles value quoting, unquoting, escaping, etc.".
  * By contrast, subroutine descriptions begin with a sentence in the imperative mood, like "Quote values in backticks.".
  * Subsequent lines of a description are more free-form.

(If you don't know what the imperative mood is, it's a command as if you're telling the subroutine what to do; e.g. "Quote values...", "Make widgets...", "Fire the missiles...".  It's **not** a description like "Quotes values..." or "It makes widgets...".)

Descriptions shouldn't be too detailed because 1) if the reader wants details they'll read the actual code and 2) those details might be rendered obsolete by code changes.  Thus descriptions should be high-level, expressing the (hopefully) singular task that the sub does.  If you find that the sub does several things, then perhaps it needs to be decomposed, or not.  See `sync_a_table()` in mk-table-sync as an example of a sub that does several things but still encapsulates a single idea.

You'll notice we use both a Parameters section and Required Arguments section (and possibly an Optional Arguments sections, too).  The Parameters are the actual parameters of the sub, which may be just `%args`, or several params like `$dbh, $db, $tbl`, or a mix like `$dsn, %args`.  It's because there's such a wide variance that we use both sections.  If there's an `%args` parameter, its key-values are listed in Required Arguments (and/or Optional Arguments).  The `$self` parameter does not need to be documented.

The `main()` sub of tools doesn't need to be documented since `main()` is a pretty universally understood concept and none of the Maatkit tools take parameters to `main()`.

# Generating the Maatkit Natural Docs Output #

First of all you'll need to checkout the `docs` directory from the svn repo with a command like `svn checkout https://maatkit.googlecode.com/svn/docs/`.  Then set the environment variable `MAATKIT_DOCS` to the full path of your copy of the docs.  This is done in addition to `MAATKIT_WORKING_COPY` and a working copy of the entire code base.  The code in `MAATKIT_WORKING_COPY` is used to generate the documentation in `MAATKIT_DOCS`.  `generate-naturaldocs` will complain and die if `MAATKIT_DOCS` is not set.

If you've never generated the nd output on your system before, it will take a few moments because it has to processes 80+ modules and 20+ tools.  The whole processes is automated by simply running `maatkit/generate-naturaldocs` without any arguments (at first).  I'll describe what happens under the hood so in case it breaks you can fix it.

`generate-naturaldocs`, when run without any options, copies every module and every tool to `MAATKIT_DOCS/nd-temp/modules` and `MAATKIT_DOCS/nd-temp/tools` respectively.  For each tool it runs `maatkit/extract-tool-package` which removes all the modules from the tool, leaving just the tool's package (e.g. `mk_table_sync` is the package in mk-table-sync).  This must be done because nd does not understand multiple packages in one file so it parses the first package and then stops.  Then nd is ran on `MAATKIT_DOCS/nd-temp` which creates the output in `MAATKIT_DOCS/code`.  nd detects when files have changed and it only parses changed files.  Since running `generate-naturaldocs` without any options creates, copies and removes the entire code base in the `nd-temp` directory, nd parses everything which is slow, so there's an alternative for active developers.

If you create the file `MAATKIT_DOCS/keep-nd-temp` then `generate-naturaldocs` will not remove `nd-temp` when it finishes.  Then you combine this with running `generate-naturaldocs` with a single argument: a tool or module name to update.  So let's say you're working on documenting `TableChunker.pm` and want to recreate the nd output for just this module without recreating everything else.  After you've generated the output once and touched `MAATKIT_DOCS/keep-nd-temp`, you run `generate-naturaldocs` like:
```
generate-naturaldocs TableChunker.pm
```
It's that simple.  `generate-naturaldocs` will copy just that module and nd will update the output for just that file.

# Next Steps #

Now you can [enhance the tools](EnhancingTools.md) and, while doing so, please add or updated the appropriate code documentation.