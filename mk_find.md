#summary Roadmap and vision for mk-find

[issues](http://code.google.com/p/maatkit/issues/list?q=tool-mk_find)

mk-find is a tool that doesn't know what size it wants to be.  It is currently too simplistic, and probably needs to be re-imagined to make it more useful.  Among the items in discussion:

  * Allow different types of objects to be found, from databases to tables to columns, etc.  See [this thread](http://groups.google.com/group/maatkit-discuss/browse_thread/thread/171be2c654f329f6/) for context.
  * Permit more flexible ways to filter objects in and out.
  * Completely rewrite the code for the find modules.  This is some of the most awkward code in Maatkit.  It needs to become iterator-driven, among other things.  It is needed for several other tools too.  See [issue 444](https://code.google.com/p/maatkit/issues/detail?id=444).
  * Test coverage.