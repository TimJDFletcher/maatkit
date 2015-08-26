#summary Standard Maatkit command line options

# Introduction #

Maatkit command line options are in the process of being standardized. Discussion is ongoing at http://groups.google.com/group/maatkit-discuss/browse_thread/thread/94df786e79d983fd and [issue 318](https://code.google.com/p/maatkit/issues/detail?id=318).

Until final decisions are made, this wiki will track the current proposal for standard Maatkit command line options.

**Please provide any feedback at the link given above.**

# Current Proposal #

Following are the currently proposed standard Maatkit options. Not all tools will have all of these options, but if a tool does have one or more of them, then its meaning is standard according to these lists:

_mysql cli-like options_:
| Option | Short Form | Meaning |
|:-------|:-----------|:--------|
| --defaults-file | -F         | Defaults file to read for MySQL options |
| --host | -h         | Connect to MySQL host |
| --password | -p         | Password for MySQL connection |
| --port | -P         | Connect to MySQL port |
| --socket | -S         | Connect to MySQL socket |
| --user | -u         | User for MySQL connection |

_additional options for tools that connect to MySQL servers_
| Option | Short Form | Meaning |
|:-------|:-----------|:--------|
| --ask-pass |            | Prompt for password for MySQL connection |
| --charset | -A         | Set character set |
| --database | -D         | Database to use for the MySQL connection |
| --set-vars |            | Set these MySQL variables after connecting |
| --where |            | WHERE clause to limit operations to certain rows |

_database/table/column/engine filter options_:
| Option | Short Form | Meaning |
|:-------|:-----------|:--------|
| --databases | -d         | List of allowed databases |
| --tables | -t         | List of allowed tables |
| --columns | -c         | List of allowed columns |
| --engines | -e         | List of allowed engines |
| --ignore-databases |            | List of databases to ignore |
| --ignore-tables |            | List of tables to ignore |
| --ignore-columns |            | List of columns to ignore |
| --ignore-engines |            | List of engines to ignore |

_miscellaneous options_:
| Option | Short Form | Meaning |
|:-------|:-----------|:--------|
| --config |            | Read this comma-separated list of config files ([issue 231](https://code.google.com/p/maatkit/issues/detail?id=231)) |
| --daemonize |            | Fork, detached from screen, and continue running in background |
| --dry-run |            | Explain what work would be done, but don't do anything |
| --help |            | Show help and exit |
| --log  |            | Send ALL output to this file when daemonized |
| --pid  |            | PID file when daemonized |
| --print |            | Print results after doing the work to generate them |
| --progress |            | Show progress report |
| --quiet | -q         | Do not print anything |
| --sentinel |            | Exit if this file exists |
| --stop |            | Create the --sentinel file and exit (TODO: verify this behavior) |
| --run-time |            | Amount of time to run before exiting (replaces --time) |
| --threads |            | Number of concurrent threads to run for parallel tasks |
| --verbose | -v         | Print more info |
| --version |            | Show version and exit |
| --wait | -w         | Wait this amount of time for some condition to become true |


# Conventions #

Command-line options should follow these conventions:

  * If the tool connects to MySQL server(s) at all, it should accept --user, --password, --ask-pass, etc.
  * If the tool uses DSNs to specify server connections, it should have some default-handling behavior, e.g. the same way mk-table-checksum does it (default to values from preceding DSNs, and then to --user, etc).
  * The trunk/maatkit/standardize-options script should not complain about the tool.

# Updated Tools #

The tools are being updated one-by-one because implementing the standardized options in a tool is not a quick task. Here is the list of tools that have and have not been updated:

| Tool | OO OptionParser ([issue 307](https://code.google.com/p/maatkit/issues/detail?id=307)) | Standardized options ([issue 318](https://code.google.com/p/maatkit/issues/detail?id=318)) | --user, --pass etc ([issue 248](https://code.google.com/p/maatkit/issues/detail?id=248)) | --config ([issue 231](https://code.google.com/p/maatkit/issues/detail?id=231)) |
|:-----|:--------------------------------------------------------------------------------------|:-------------------------------------------------------------------------------------------|:-----------------------------------------------------------------------------------------|:-------------------------------------------------------------------------------|
| mk-archiver | [r3486](https://code.google.com/p/maatkit/source/detail?r=3486)                       | [r3874](https://code.google.com/p/maatkit/source/detail?r=3874)                            | uses DSNs                                                                                | [r3486](https://code.google.com/p/maatkit/source/detail?r=3486)                |
| mk-checksum-filter | [r3591](https://code.google.com/p/maatkit/source/detail?r=3591)                       | [r3591](https://code.google.com/p/maatkit/source/detail?r=3591)                            | doesn't connect                                                                          |                                                                                |
| mk-deadlock-logger | [r3536](https://code.google.com/p/maatkit/source/detail?r=3536)                       | [r3559](https://code.google.com/p/maatkit/source/detail?r=3559)                            | [r3559](https://code.google.com/p/maatkit/source/detail?r=3559)                          | [r3559](https://code.google.com/p/maatkit/source/detail?r=3559)                |
| mk-duplicate-key-checker | [r3363](https://code.google.com/p/maatkit/source/detail?r=3363)                       | [r3363](https://code.google.com/p/maatkit/source/detail?r=3363)                            | yes                                                                                      | [r3363](https://code.google.com/p/maatkit/source/detail?r=3363), [r3379](https://code.google.com/p/maatkit/source/detail?r=3379) |
| mk-fifo-split | [r3689](https://code.google.com/p/maatkit/source/detail?r=3689)                       | [r3689](https://code.google.com/p/maatkit/source/detail?r=3689)                            | doesn't connect                                                                          |  [r3689](https://code.google.com/p/maatkit/source/detail?r=3689)               |
| mk-find | [r3676](https://code.google.com/p/maatkit/source/detail?r=3676)                       | [r3679](https://code.google.com/p/maatkit/source/detail?r=3679), awaiting feedback         | yes                                                                                      | [r3676](https://code.google.com/p/maatkit/source/detail?r=3676)                |
| mk-finger | NA                                                                                    | NA                                                                                         | NA                                                                                       | NA                                                                             |
| mk-heartbeat | [r3549](https://code.google.com/p/maatkit/source/detail?r=3549)                       | [r3549](https://code.google.com/p/maatkit/source/detail?r=3549)                            | yes                                                                                      | [r3549](https://code.google.com/p/maatkit/source/detail?r=3549)                |
| mk-loadavg |  [r3877](https://code.google.com/p/maatkit/source/detail?r=3877)                      |  [r3877](https://code.google.com/p/maatkit/source/detail?r=3877)                           | yes                                                                                      |  [r3877](https://code.google.com/p/maatkit/source/detail?r=3877)               |
| mk-log-player | [r3484](https://code.google.com/p/maatkit/source/detail?r=3484)                       | [r3484](https://code.google.com/p/maatkit/source/detail?r=3484) (partly)                   | [r3484](https://code.google.com/p/maatkit/source/detail?r=3484)                          | [r3484](https://code.google.com/p/maatkit/source/detail?r=3484)                |
| mk-log-server | NA                                                                                    | NA                                                                                         | NA                                                                                       | NA                                                                             |
| mk-parallel-dump | [r3588](https://code.google.com/p/maatkit/source/detail?r=3588)                       | [r3588](https://code.google.com/p/maatkit/source/detail?r=3588)                            | yes                                                                                      | [r3588](https://code.google.com/p/maatkit/source/detail?r=3588)                |
| mk-parallel-restore | [r3598](https://code.google.com/p/maatkit/source/detail?r=3598)                       | [r3598](https://code.google.com/p/maatkit/source/detail?r=3598)                            | yes                                                                                      | [r3598](https://code.google.com/p/maatkit/source/detail?r=3598)                |
| mk-profile-compact | [r3473](https://code.google.com/p/maatkit/source/detail?r=3473)                       | [r3473](https://code.google.com/p/maatkit/source/detail?r=3473)                            | doesn't connect                                                                          | [r3473](https://code.google.com/p/maatkit/source/detail?r=3473)                |
| mk-query-digest | [r3490](https://code.google.com/p/maatkit/source/detail?r=3490)                       |  [r3610](https://code.google.com/p/maatkit/source/detail?r=3610)                           |                                                                                          | [r3490](https://code.google.com/p/maatkit/source/detail?r=3490)                |
| mk-query-profiler | [r3473](https://code.google.com/p/maatkit/source/detail?r=3473)                       | [r3473](https://code.google.com/p/maatkit/source/detail?r=3473)                            | yes                                                                                      | [r3473](https://code.google.com/p/maatkit/source/detail?r=3473)                |
| mk-show-grants | [r3555](https://code.google.com/p/maatkit/source/detail?r=3555)                       | [r3555](https://code.google.com/p/maatkit/source/detail?r=3555)                            | yes                                                                                      | [r3555](https://code.google.com/p/maatkit/source/detail?r=3555)                |
| mk-slave-delay | [r3353](https://code.google.com/p/maatkit/source/detail?r=3353)                       | [r3390](https://code.google.com/p/maatkit/source/detail?r=3390), [r3504](https://code.google.com/p/maatkit/source/detail?r=3504) | [r3392](https://code.google.com/p/maatkit/source/detail?r=3392), [r3422](https://code.google.com/p/maatkit/source/detail?r=3422) | [r3353](https://code.google.com/p/maatkit/source/detail?r=3353)                |
| mk-slave-find | [r3426](https://code.google.com/p/maatkit/source/detail?r=3426)                       | [r3426](https://code.google.com/p/maatkit/source/detail?r=3426)                            | yes                                                                                      | [r3426](https://code.google.com/p/maatkit/source/detail?r=3426)                |
| mk-slave-move | [r3428](https://code.google.com/p/maatkit/source/detail?r=3428)                       | [r3428](https://code.google.com/p/maatkit/source/detail?r=3428)                            | [r3428](https://code.google.com/p/maatkit/source/detail?r=3428)                          | [r3428](https://code.google.com/p/maatkit/source/detail?r=3428)                |
| mk-slave-prefetch | [r3439](https://code.google.com/p/maatkit/source/detail?r=3439)                       | [r3439](https://code.google.com/p/maatkit/source/detail?r=3439), [r3506](https://code.google.com/p/maatkit/source/detail?r=3506) | yes                                                                                      | [r3439](https://code.google.com/p/maatkit/source/detail?r=3439)                |
| mk-slave-restart | [r3412](https://code.google.com/p/maatkit/source/detail?r=3412)                       | [r3412](https://code.google.com/p/maatkit/source/detail?r=3412), [r3508](https://code.google.com/p/maatkit/source/detail?r=3508) | yes                                                                                      | [r3412](https://code.google.com/p/maatkit/source/detail?r=3412)                |
| mk-table-checksum | [r3574](https://code.google.com/p/maatkit/source/detail?r=3574),  [r3575](https://code.google.com/p/maatkit/source/detail?r=3575) | [r3574](https://code.google.com/p/maatkit/source/detail?r=3574),  [r3575](https://code.google.com/p/maatkit/source/detail?r=3575) | yes                                                                                      | [r3578](https://code.google.com/p/maatkit/source/detail?r=3578)                |
| mk-table-scan | NA                                                                                    | NA                                                                                         | NA                                                                                       | NA                                                                             |
| mk-table-sync | [r3583](https://code.google.com/p/maatkit/source/detail?r=3583)                       | [r3583](https://code.google.com/p/maatkit/source/detail?r=3583)                            | uses DSNs                                                                                | [r3583](https://code.google.com/p/maatkit/source/detail?r=3583)                |
| mk-visual-explain | [r3337](https://code.google.com/p/maatkit/source/detail?r=3337)                       | [r3337](https://code.google.com/p/maatkit/source/detail?r=3337)                            | yes                                                                                      | [r3349](https://code.google.com/p/maatkit/source/detail?r=3349)                |

Tools marked "NA" are skeleton tools, or not in development, etc.