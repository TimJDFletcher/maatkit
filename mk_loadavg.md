[issues](http://code.google.com/p/maatkit/issues/list?q=label:Tool-mk_loadavg)

This tool is a partially built proof of concept at the moment.  The concept is explained in [issue 124](https://code.google.com/p/maatkit/issues/detail?id=124).  The idea is a tool that can watch various metrics of server load and take certain actions when thresholds are exceeded.  A very simple example is to watch for more than 5 processes in Locked status and capture a snapshot of `SHOW FULL PROCESSLIST` so a human has the evidence necessary to do forensic work.

Recent changes added a lot more complexity to the tool, and it is now pretty hard to use without studying the examples in the man page, even if you know the tool well.  We need to build a more intuitive syntax for specifying thresholds.