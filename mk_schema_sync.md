[issues](http://code.google.com/p/maatkit/issues/list?q=label:Tool-mk_schema_sync)

This tool does not exist.  The idea is a sister tool to [mk\_table\_sync](mk_table_sync.md), which compares and synchronizes data.  This one can compare and synchronize table structures.  There is prior art on this point; see [issue 438](https://code.google.com/p/maatkit/issues/detail?id=438).  It is important to do both static and (optionally) dynamic analysis.  Only by sampling data can we know that a column was renamed, for example, rather than dropped and added.

The roadmap is to

  * Create a set of modules that can compare schema and generate ALTER TABLE statements
  * Add dynamic analysis to inspect data and see if it's possible to learn additional information about the tool
  * Look at prior art, such as SQLYog's functionality, or [this tool](http://devart.com/blogs/dbforge/?p=244)