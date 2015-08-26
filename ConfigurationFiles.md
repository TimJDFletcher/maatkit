We have a request to make Maatkit tools able to read configuration files.  See [issue 231](https://code.google.com/p/maatkit/issues/detail?id=231).  This wiki page documents what we think we'll do, and then we'll move it to make it document what we have done.

# Functionality #

Each tool will read configuration from several places, in the following order:

  * the global Maatkit config file
  * the global tool-specific config file
  * the user's Maatkit config file
  * the user's tool-specific config file
  * the command-line options

Things that come later will override things that come earlier.  That is, the defaults from the global file will always be overridden by the tool-specific file; the command-line options will override that again.

# Naming #

We had a lot of discussion on the mailing list about naming conventions (.cnf or .conf suffix?)  The pro-conf people note that this is conventional usage; the pro-cnf people note that this mimics MySQL's usage.  IMO we should follow the convention, not MySQL.  The MySQL configuration-file naming is not what we should emulate in several ways, including the basename (why is it my.cnf rather than mysql.cnf?).

Proposal:

  * use .conf filename extension.

# Location #

This one is not controversial, at least on POSIX systems.  (What about Windows?)

Proposal:

  * /etc/maatkit/maatkit.conf is the global Maatkit config file
  * /etc/maatkit/mk-(toolname).conf is the global tool-specific config file
  * $HOME/.maatkit.conf is the user's Maatkit config file
  * $HOME/.mk-(toolname).conf is the user's tool-specific config file

# Related Command-Line Options #

We need a new command-line option:

  * --config (array of files)

If specified, it must be specified first on the command-line.  It works like this: before parsing command-line options from the config file, peek at @ARGV and if the first item is --config then read the specified files and shift @ARGV (more on this later).  If the first item isn't --config, then read the default files before parsing options.  Either way, the OptionParser should have special behavior: it should set the option to its default value if it's unset.  That way we can see the defaults with --help and see what files it's going to try to read.

If the first item in @ARGV is --no-config then don't read any option files at all, just shift @ARGV.

This also means that giving --config or --no-config as anything but the first item should be an error.  So if we actually see --config or --no-config on the command line after it is shifted off the front of @ARGV, we should complain.  We can add a special type of option and embed it in the POD, like "type: illegal" or something.

# Overriding #

Some options aren't possible to cancel out, at the time of writing.  This could be a problem.  If the global configuration file says "foo=1" and the user doesn't want that, there would really only be two options:

  1. The user can use --no-config and lose ALL global defaults.
  1. We can give the user some extra power to cancel options.

Proposal:

  * Let's punt on this for the moment, and see if a fix is requested.
  * If a fix is requested, we can add a hidden --skip name prefix that will completely delete an option, no matter where it's given.  (If setting it to a different value is desired, the user could just specify the value and override the global default.)

# File Format #

Generally, it'll mimic a pretty standard format: comments, name-value format.  There's also a facility for specifying files or DSNs, which aren't parsed as options when they're seen in @ARGV.

Proposal:

  * A # (hash) character preceded by one or more whitespace characters means the whitespace, the hash, and the rest of that line is a comment.
  * One option per line.
  * Only long options are permitted in config files.
  * After a line containing only two dashes, further lines are files/DSNs.

# Functionality #

I think what we want to do is something like the following:

  * Read the files in order (later files override earlier ones).
  * Read each line in the file.
  * Strip out comments and leading/trailing whitespace.
  * Skip empty lines.
  * Prefix each line with two hyphens and split it into tokens.
  * Push the tokens onto an array.
  * When -- is encountered, stop prefixing lines with hyphens.
  * After this is all done, prepend the whole array onto the front of @ARGV.

# Example #

Given the following maatkit.conf,

```
foo=bar
verbose
```

And the following mk-toolname.conf,

```
# This is some comment
quiet
--
/path/to/file
```

We will parse the first file and end up with the following array:

```
"--foo" "bar" "--verbose"
```

After that, we'll read the second file and add on, so we get

```
"--foo" "bar" "--verbose" "--quiet" "/path/to/file"
```

The user's configuration files will be read in the same fashion.  Then, supposing that we called mk-toolname --verbose /path/to/file2, we will end up with

```
"--foo" "bar" "--verbose" "--quiet" "/path/to/file" "--verbose" "/path/to/file2"
```

And that will be the final @ARGV.

# Outstanding Issues #

There are some possible issues:

  * Forwards and backwards compatibility.  The mysql command-line option convention lets you prefix options with --loose so they aren't thrown as errors if they're not recognized.  Can/should we do the same thing?  Or is that a bridge we should cross when we come to it?
  * Multiple-instance support.  Suppose I want to run 100 instances of mk-slave-delay, each pointing to a different server, all reading from one config file.  How do we do this?  Is this even worth thinking about?  Are we making any decisions here that will make more flexibility in the future really hard?