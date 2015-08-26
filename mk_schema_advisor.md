#summary Roadmap and vision for mk-schema-advisor

[issues](http://code.google.com/p/maatkit/issues/list?q=label:Tool-mk_schema_advisor)

This tool will do static and dynamic analysis of schema.  It will replace [mk\_duplicate\_key\_checker](mk_duplicate_key_checker.md) and add more functionality.

The roadmap is to write a specification and plan the implementation.

## Functionality ##

The following ideas were in the mk-schema-advisor skeleton script.  I've placed them here for now; later, they'll probably be moved to issues once the tool is more developed.  Some may be duplicates or invalid or not feasible.  I'm sure we'll discuss them later, too.  There is also some helpful stuff to look at in trunk/mk-audit/TODO, which is removed but is in SVN history in [r5590](https://code.google.com/p/maatkit/source/detail?r=5590).

  1. estimate how much smaller we can make a table by optimizing its data types.  Calculate the space savings for primary/secondary keys for InnoDB.  See Percona customer case #2389.
  1. Permit to read from a file so we can do something like "mysqldump --no-data > file; mk-schema-advisor < file".
  1. produce a detailed per-db, per-tbl schema report showing size, index size, engine, number of indexes, number of columns etc for each table.  Maybe also mention unusual data types in the table, or a summary of the data types.  Also show triggers.
  1. for datetime columns, check a naming convention and guess whether they can be timestamp instead.  'ts', 'created\_at', 'last\_updated'
  1. Try to find ip adress columns that are stored as varchar (again, naming convention).  Names I've seen: ip
  1. Alert if there are columns in different tables with the same name and different data types.  See email 25020 on Percona issue id 1881 for an example, but don't do an information\_schema query to find this out.
  1. For each table with an auto-inc PK and a timestamp, try to guess how many rows/day it grows, both overall and more recently, by splitting up and getting the timestamps at various points in th table.
  1. Draw a histogram of these values. Indexes:
  1. Top N tables with the most/least indexes
  1. Compute indexes that are not very selective
  1. Storage engines
  1. views
  1. merge tables (how many are broken)
  1. check if MERGE tables sum up the size of their contained tables in SHOW TABLE STATUS
  1. look for this error in SHOW TABLE STATUS: Unable to open underlying table
  1. partitioned tables
  1. count of partitioned tables; this can be seen in Create\_options in show table status, or from i\_s tables, or create table
  1. look for partitioned tables that don't have many future partitions: `) ENGINE=InnoDB DEFAULT CHARSET=latin1 /*!50100 PARTITION BY RANGE (YEAR(day)) (PARTITION p_2006 VALUES LESS THAN (2007) ENGINE = InnoDB, PARTITION p_2007 VALUES LESS THAN (2008) ENGINE = InnoDB, PARTITION p_2008 VALUES LESS THAN (2009) ENGINE = InnoDB, PARTITION p_catchall VALUES LESS THAN MAXVALUE ENGINE = InnoDB) */`
  1. guess from column names how they are related to other tables.  account\_id can mean this column is a FK to an account table.  If so, check for NULL-ability vs. presence of NULL in the table
  1. Look for tables that have silly schema, like a lot of varchar(255) Other common auto-generated length is varchar(50).  If many varchar have the same length, raise an alarm.  In fact, a schema-wide summary of data types and lengths, and the number of each, would be very useful.
  1. Look for non-recommended data types, like float(M,N) and BIT.  Also any type that has a non-default display width: int([^11]) is a warning sign that they don't understand the display widths
  1. If a table has two potential FK columns, like post\_id and author\_id, and at the same time has an autoinc PK, raise a notice that maybe the PK should be post\_id,author\_id.
  1. if a table has one autoinc PK and another int UNIQUE, raise a notice that maybe it should drop the autoinc and promote the UNIQUE to PK.
  1. for InnoDB tables, a key that has the PK appended is redundant.
  1. pack\_keys=1 is probably a mistake
  1. tables that have only primary, unique, and one other key with many values are probably a mistake: the user probably thinks a key on (a,b,c) is enough for queries on any of those columns.
  1. tables that have a single index on every column are probably a mistake.
  1. look for columns named UUID or GUID or session\_id which may contain hex data stored as strings, which would be better stored unhexed in binary
  1. Check LIMIT 1 from all columns and look for UUID/GUID-looking values.
  1. Look for nullable columns that contain no NULLs, especially indexed columns
  1. Automatically run PROCEDURE ANALYSE on tables that look bad.
  1. For each indexed int, check whether it's getting close to the limit of the values it can hold with SELECT MAX(...).
  1. Determine the thoroughness of the search by how large the DB/table is.
  1. auto-generate sql to show count(distinct col) for all columns
  1. auto-generate sql to show col,count(`*`) group by 1 order by 2 desc limit 10 so we can find the skew of the distribution.
  1. for indexed columns, find ones that are not very selective
  1. Look for absence of unsigned
  1. Look for someting like DECIMAL(31,0)
  1. Check for things that are incompatible with different storage engines, such as --incompatible-with=innodb to examine specific features like hash indexes, fulltext
  1. Support percona extensions to show most active users/tables and if they are not available, just say something about it.
  1. Run filefrag on data files?
  1. note if a storage engine is enabled but not in use -- but check for permissions to see everything before warning about this, otherwise can have false positive
  1. Look for fragmentation from SHOW TABLE STATUS (as reported by innodb free space, depending on file-per-table; or for single-file, amount of space used/free in ibdata1) or for myisam, Data\_free field; show worst 5 fragmented in tabular format as usual
  1. check if the InnoDB plugin is being used.  Report some stats about number of tables using compression or other specific features.
  1. Look at http://code.google.com/p/check-unused-keys/ for inspiration and see if any useful features can be combined.
  1. Look at http://www.mysqlperformanceblog.com/2010/01/05/upgrading-mysql/ for some inspiration for features for checking whether something won't upgrade right.
  1. If a table is like create table abc(id pk auto\_inc, abc\_id int, unique(abc)) then suspect that surrogate primary key is being taken too far.  abc\_id should be the primary key.
  1. Look for a bunch of columns with one index per column, one column per index.  This is probably a naive indexing scheme, especially if it's duplicated across all tables.
  1. int(N) should almost never be used unless it's the default.  Warn if non-default display widths are used.  Warn about width being specified for float/double, it messes with rounding upon storing the value.
  1. Warn if enums aren't NOT NULL.
  1. If a table is referred to by another table and has only a limited number of values, it might be better off as an enum().
  1. Look if tinyint columns have just 1/0 in them.  If so and there are a bunch of them in the table, suggest different boolean type.