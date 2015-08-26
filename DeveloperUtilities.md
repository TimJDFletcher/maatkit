#summary About the tools in the trunk/maatkit/ directory

# Introduction #

The trunk/maatkit directory has a number of useful tools for Maatkit developers to use while they write code.

## add-changelog-entry ##

Adds the specified message to the top of the changelog for every modified tool.

## alpha-options.pl ##

Read the command-line options in a tool and warn if the options are in a different order in the POD than they'll appear in the --help output.

## bump-version ##

Add a changelog entry to every Changelog file, and add a line that shows the current date and increments the tool's version in the Changelog.

If you use the --new option, it'll only bump the version for "unclosed" Changelogs, and it'll let you omit the comment.

## check-pod ##

Runs podchecker on every tool and checks that POD headings are in standard order.  Look inside pod-check to see what standard order it.

## count\_tests.pl ##

Counts the number of tests in a test tool to make sure that the USE Test::More line specifies the correct number of tests.

## insert\_module ##

Read in the standard input, and replace the desired module by the contents (sans comment lines) of the most recent version of the module.  You can use this from Vim!  Example:

```
 :%!../maatkit/insert_module TableParser
```

## latest-changelog ##

Print the latest paragraph from each Changelog entry.  Also validates that Changelog files are in the desired format, with the Version line, correct usage of spaces instead of tabs, etc.

## list\_all\_scripts.sh ##

A way to find tools easily.

## new-module ##

An easy way to make a new module in common/ and a skeleton test in common/t/.

## show-module-status ##

Reads all mk-toolname files and verifies that each embedded module is formatted correctly (so update-modules will work right).  Also compares the version of each module with the latest version in common/ and if they're different, prints a note about it.

## standardize-options ##

Prints out tools whose POD text for standard options does not match the standard text.

## tabulate-options.pl ##

Prints every module's command-line option names in a format suitable for loading in a spreadsheet.

## test.sh ##

Runs all tests in all mk-toolname/t directories.  Automatically run by the Makefile.  If you want it to exit without doing anything, set the NO\_TESTS environment variable.

## update-modules ##

Updates embedded modules for all files within a package subdirectory, so they match the latest code from common/.  It actually uses insert\_module behind the scenes.

The first argument needs to be the tool name.  The second is optional: the name of the module to update.  Without the second option, all modules are updated.

## tcpdump-grep ##

Takes a perl regex and reads tcpdump from STDIN or files, and prints out packets that match the pattern.

## tcpdump-decode ##

Reads files or STDIN, prints packets, and prints a plaintext version of the packet's data after each packet.

Example:

```
tcpdump-grep 127.0.0.1.52592 sample.txt | tcpdump-decode
```