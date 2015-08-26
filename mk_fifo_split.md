[issues](http://code.google.com/p/maatkit/issues/list?q=tool-mk_fifo_split)

mk-fifo-split is a little unlike other tools.  It isn't really a utility for MySQL, although it turns out that it is quite useful for loading large data in a kinder way.

It is very simple and it will probably stay that way.  It could be enhanced slightly to make it more user-friendly:

  * Handle binary files if necessary with binmode.
  * Permit reading a slice from the middle of the file (perhaps with --limit and --offset options).
  * Print out the stopping point on exit, to make it easier to resume.
  * Enhance progress messages.  Make it print progress percent and ETA when the size of the file is known (e.g. it is reading from a file, not STDIN).  Make it possible to send it a USR1 or similar signal to make it print progress.  See http://www.perlmonks.org/?node_id=698607 for inspiration.