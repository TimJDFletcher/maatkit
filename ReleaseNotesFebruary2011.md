Maatkit version 7284 has been released: http://code.google.com/p/maatkit/

In this month's release, two tools receive a lot of enhancement, and
two other tools are deprecated.  These latter tools are mk-parallel-
dump and mk-parallel-restore.  As their PODs now indicate, "This tool
is deprecated because after several complete redesigns, we concluded
that Perl is the wrong technology for this task. ... It remains useful
for some people who we know aren't depending on it in production, and
therefore we are not removing it from the distribution."

Receiving the enhancements are mk-kill and mk-query-digest.  Several
options were added and removed from mk-kill, some bugs fixed, and the
POD was updated with further explanations about how the tool works.  A
bug with mk-query-digest --interval was fixed, and two options were
added: --variations and --run-time-mode.  These options introduce
helpful new functionality.  --run-time-mode=event, for example, makes
--run-time operate on "log time" (timestamps from the log) instead of
wallclock time.

Below is the full changelog for this release...
```
Changelog for mk-kill:

2011-02-09: version 0.9.9

   * Removed option --[no]only-oldest (issue 1221).
   * Removed option --all-but-oldest (issue 1221).
   * Changed option --all to --match-all (issue 1221).
   * Added option --victims (issue 1221).
   * Added option --any-busy-time.
   * Group and matching logic was incorrect (issue 1221).
   * Tool crashed if connection to be killed was already gone.

Changelog for mk-parallel-dump:

2011-02-09: version 1.0.28

   * Officially deprecated this tool and noted that in the documentation.

Changelog for mk-parallel-restore:

2011-02-09: version 1.0.24

   * Officially deprecated this tool and noted that in the documentation.

Changelog for mk-query-digest:

2011-02-09: version 0.9.26

   * --interval did not always work (issue 1186).
   * Added --run-time-mode option (issue 1150).
   * Added --variations option (issue 511).

Changelog for mk-variable-advisor:

2011-02-09: version 1.0.2

   * The tool did not prompt for a password with --ask-pass (issue 1243). 
```