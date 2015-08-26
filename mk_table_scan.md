[issues](http://code.google.com/p/maatkit/issues/list?q=label:Tool-mk_table_scan)

This tool should be renamed something like mk-load-index.  Its purpose is to scan tables and indexes in order to load them into the server's memory (OS cache, key buffer, or buffer pool).  There is a [thread](http://groups.google.com/group/maatkit-discuss/browse_thread/thread/8e55c96c6d438da7) on this on the mailing list.

It is currently just a proof of concept, but a few hours of work should round it out pretty well.