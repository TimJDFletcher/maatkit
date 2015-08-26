[issues](http://code.google.com/p/maatkit/issues/list?q=label:Tool-mk_table_sync)

This is a very important tool that is still only about half done.  It is quite complex and difficult to build this functionality.  The issue list is basically packed with things that need to be done.  The roadmap is generally to make the tool do "the right thing" more, and let users have more control when that's not what they want.  Roughly in order,

  * Correctness and sanity checks.  Fix the bugs.
  * Functionality enhancements to control the tool more finely and make it more flexible.  About half the issues qualify for this description.  It needs more options, filters, and special cases.  See for example [issue 877](https://code.google.com/p/maatkit/issues/detail?id=877) and [issue 376](https://code.google.com/p/maatkit/issues/detail?id=376).
  * More error handling so it just keeps going.  See for example [issue 78](https://code.google.com/p/maatkit/issues/detail?id=78).
  * Speed improvements.  Profiling shows that DBI preparing statements is a performance killer.  So are some of the tight loops.  Re-profile and then assess the [performance](http://code.google.com/p/maatkit/issues/list?q=label:Tool-mk_table_sync+label:Tag-performance) issues.
  * Two-way (bi-directional) synchronization for some cases ([issue 464](https://code.google.com/p/maatkit/issues/detail?id=464))