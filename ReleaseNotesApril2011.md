Maatkit version 7410 has been released: http://code.google.com/p/maatkit/

In this month's release, a few character set related bugs were fixed
in mk-archiver, a bug in mk-query-digest involving --review-history
was fixed, and two bugs in mk-kill were fixed: it didn't read an
implicitly piped STDIN and it crashed if no connection-related options
(e.g. --host, --port, etc.) were given.  Also, mk-kill --heartbeat was
renamed to --verbose.

A couple of tools received enhancements, like mk-table-checksum no
longer sleeping (for --sleep) after the last or only chunk and mk-
duplicate-key-checker avoiding crashes if tables it once saw are
dropped during execution.

mk-config-diff is a new tool in this release (brining the total number
of released Maatkit tools to 29).  As its --help says:

```
mk-config-diff diffs MySQL configuration files and server variables.
CONFIG can be a filename or a DSN.  At least two CONFIG sources must
be given.  Like standard Unix diff, there is no output if there are no
differences.

Usage: mk-config-diff [OPTION...] CONFIG CONFIG [CONFIG...]
```

For example, you can do "mk-config-diff /etc/my.cnf h=localhost" to
see if MySQL's active/running configuration as reported by SHOW
VARIABLES matches the configuration specified in the /etc/my.cnf
option file (assuming you started MySQL with that option file).  mk-
config-diff understands server system variables from SHOW VARIABLES
(either live from the server or the output saved to a file), option
files (the [mysqld](mysqld.md) section), my\_print\_defaults and mysql --help --
verbose.  Give it a try, and please report any false-positives as
bugs.

Thanks to the multitude of people and companies who reported bugs,
provided patches, and sponsored development!

Following is the complete changelog for this release.
```
Changelog for mk-archiver:

2011-04-04: version 1.0.27

   * Different character sets could have caused data loss (issue
1225).
   * --file was not opened using the specified --charset (issue 1229).
   * --charset=UTF8 did not enable mysql_enable_utf8 (issue 1282).
   * Added --[no]check-charset (issue 1225).

Changelog for mk-config-diff:

2011-04-04: version 1.0.0

   * Initial release.

Changelog for mk-duplicate-key-checker:

2011-04-04: version 1.2.15

   * Tool crashed if table dropped during execution (issue 1235).

Changelog for mk-kill:

2011-04-04: version 0.9.10

   * Tool crashed if no connection opts (--host, etc.) were given
(issue 1213).
   * Renamed option --heartbeat to --verobse (issue 1215).
   * Implicitly piped STDIN was not read (issue 1214).

Changelog for mk-query-digest:

2011-04-04: version 0.9.28

   * Minimum 2-column query review history table did not work (issue
1265).

Changelog for mk-table-checksum:

2011-04-04: version 1.2.21

   * --sleep slept after the last or only chunk (issue 1256). 
```