#summary Roadmap and vision for mk-query-advisor

[issues](http://code.google.com/p/maatkit/issues/list?q=label:Tool-mk_query_advisor)

This tool does not exist.  Its purpose is to do static analysis of queries by examining patterns within the SQL, and optionally to do dynamic analysis by connecting to a server and examining EXPLAIN, looking at samples of data, examining cardinality, and so on.  The initial issue report is [issue 861](https://code.google.com/p/maatkit/issues/detail?id=861).

An example is to look for queries that have `IN()` or `NOT IN()` subqueries, which are poorly optimized in current versions of MySQL.  These can be recognized simply by looking at the SQL.