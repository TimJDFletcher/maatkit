# Design Goals #

Here are some of Maatkit's primary design goals:

  * Focus.  Do something and do it well.  Do not try to boil the ocean.
  * Tools should be self-contained.  Download and run.  No installation needed.
  * Create as few dependencies as possible.  Core Perl modules are generally OK, but anything that isn't preinstalled in 99% of Perl users' machines should be avoided, or made optional (e.g. detect it if it's there, degrade gracefully if not).  Exceptions are DBI and DBD::mysql, and in some cases Time::HiRes.
  * Accurate, complete documentation.  The best way to do this is to generate the command-line help and the program's actual behavior from the documentation itself!  As a result, we embed specially formatted instructions into the native POD documentation at the end of every tool, and we have a large amount of code to interpret that and turn it into instructions to the tool.  We continue to try to improve on this.
  * Follow the principle of least surprise.  We try to match MySQL's client programs' behavior when it makes sense.  And we strive for a common look and feel across all tools, and common command-line options when it makes sense.
  * Build stable, efficient, provably correct tools.  Maatkit is mission critical for its primary sponsor (Percona), many of Percona's clients, and many others including large companies, military projects, healthcare providers and space programs.  This is why we have a test suite, and why we try to practice test-driven development.
  * Automate everything possible.  We have limited resources; we try to make the most of them.
  * Work for platform-independence when it makes sense.  For example, some of the tools are daemonizable on POSIX platforms, and most will run on Windows.  Some tools work with PostgreSQL.