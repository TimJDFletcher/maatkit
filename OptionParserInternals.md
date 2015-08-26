#summary Internal mechanics of OptionParser.pm

# Synopsis #

The common module OptionParser.pm is responsible for converting a tool's POD OPTIONS items to Getopt::Long option specs and parsing command line arguments from @ARGV accordingly.

The goal is to derive the command-line help output from the options that are accepted, and to derive the options from the POD, so there is no duplication and everything always stays in sync.  It is like an advanced version of pod\_to\_usage().

# Format of Options in the POD #

Each option in the OPTIONS secion of the POD must have the following form to be parsed correctly:
```
   =item --OPTION_NAME

   ATTRIBUTES

   HELP_DESCRIPTION

   FULL_DESCRIPTION
```

OPTION\_NAME is the full (long) name of the option, like --foo. Optionally, the name can be prefixed with `[`no`]` (--`[`no`]`foo) to make the option negatable.

ATTRIBUTES is a single, optional line that allows you to specify the following attributes:
  * `short form`: short name of the option, like -f (short for --foo)
  * `type`:       standard Getopt types (sif) and more; see Option Types below
  * `default`:    option's default value if none is given on the command line
  * `cumulative`: if 'yes' then sets the Getopt + spec so that "The option does not take an argument and will be incremented by 1 every time it appears on the command line."
Each attribute is given like `attribute: value` and multiple attributes are separated by semicolons. Example:
> `short form: -w; type: time; default: 5m`

HELP\_DESCRIPTION is a single line that briefly describes the option. It is what --help prints about the option. Technically, it is optional if there is at least one sentence in FULL\_DESCRIPTION. In such a case, that first full period-terminated sentence in FULL\_DESCRIPTION is printed by --help.

FULL\_DESCRIPTION is optional (unless, as noted above, no HELP\_DESCRIPTION is given). Here you can write your novel about the gory details of the option.

## Option Types ##

There are a few different data types that you can specify for an option.

  * string : standard Getopt type
  * int    : standard Getopt type
  * float  : standard Getopt type
  * Hash   : hash, formed from a comma-separated list
  * hash   : hash as above, but only if a value is given
  * Array  : array, similar to Hash
  * array  : array, similar to hash
  * DSN    : DSN, as provided by a DSNParser which is in $self->{dsn}
  * size   : size with kMG suffix (powers of 2^10)
  * time   : time, with an optional suffix of s/h/m/d

The difference between an Array, array, Hash and hash is only in the type of the value you get from OptionParser::get().  All of them accept a comma-separated list.  The ones that are lowercase will return undef if the option wasn't given.  The uppercase ones will return an empty but defined value if an option wasn't given.

# Magical Instructions #

The POD can contain three kinds of magical instructions: magically named paragraphs of text, embedded instructions within an option, and instructions that precede options.

## Magic Paragraphs ##

A magic paragraph is the paragraph following some magic word.  You can retrieve it with the read\_para\_after() method.  For an example, see mk-query-digest and look for MAGIC\_createreview (the magic word).  You just have to embed the magic word in the preceding paragraph, and then specify it in the call to read\_para\_after().

## Embedded Instructions ##

The command-line option's description can have special words in it to instruct the OptionParser to treat it a certain way.  Note that when embedded in the POD, "the description" means the first sentence in the item's documentation.  Here are the behaviors:

  * "required".  The presence of this word makes OptionParser throw an error if there is no value for the option.
  * "default".  If you say "default" then anything after that word is treated as the default value for the option.  (Be careful, it's easy to slip and put "default" in the option text.)
  * "disables".  If you say "disables --foo", then the presence of the option will set --foo to 0.
  * "must be the first option".  The presence of this phrase makes this option illegal to give as anything but the first option on the command-line.

Magical embedded instructions such as "disables --foo" can have embedded POD links in them, too.  So you can also say 'disables L<"--foo">' so the POD will linkify it.

## Instructions That Precede Options ##

You can put some paragraphs right after the OPTIONS heading, and before the list of options.  These are examined for magical instructions about the options.

  * "default to".  If the value "default to" appears in the paragraph, OptionParser scans the paragraph for things that look like option names.  If the options are DSNs, then the second option's values are defaulted to values from the first one.
  * TODO: there are more.  Fill in more things here...

## --config: The Magical, Meta-option ##

--config has an intrinsic, hard-coded rule: if given, it must be the first option on the command line. OptionParser enforces this rule automatically when the --config option appears in a tool. Therefore, this rule does not need to be stated in the POD, but it should be mentioned like:
```
=item --config

type: Array

Read this comma-separated list of config files.

If specified, this must be the first option on the command line.
```

--config must be type Array (this is not intrinsic or automatically enforeced).

See also [ConfigurationFiles](ConfigurationFiles.md).