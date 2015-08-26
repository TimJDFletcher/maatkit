#summary Getting started hacking on Maatkit

Here's what every Maatkit developer should have, know and do.  Even if you're just finding and submitting bugs--which is very important  work--this information largely applies to you, too.

There are just three steps to get started:

  1. Get the programs, packages, modules, etc. to meet the system requirements
  1. Request commit access if you plan to commit code
  1. Checkout a copy of the Maatkit code from Google Code using svn

But first there's something so important that every developer should know: MKDEBUG.  We'll explain MKDEBUG first then cover the 3 setup steps.

# MKDEBUG #

Debug output for every tool is enabled and prints to STDERR if the environment variable MKDEBUG is true.  You can enable this on a per-run basis, like:

```
MKDEBUG=1 ./mk-query-digest slow.log
```

That runs mk-query-digest with debug output for just that run.  If you `export MKDEBUG=1` then every run of every Maatkit tool will print debug info (until you logout and log back in; or forever if you set this in your login init script, like .bashrc).

Debug output exposes a world of information that is crucial for developers.  MKDEBUG is the only way to get this information.  But be careful!  MKDEBUG prints **a lot** of information, potentially Gigs and Gigs of extra information.

If you want to capture a tool's output along with all its debug output to one file, do like:

```
MKDEBUG=1 ./mk-query-digest slow.log > out.txt 2>&1
```

All output will be written to file `out.txt`.  This debug information is important if you intend to [[fix bugs](http://code.google.com/p/maatkit/wiki/FixingBugs).

Now let's look at the 3 setup steps...

# 1. System Requirements #

  1. A computer running a Unix operating system (you can try on Windows but that's largely unknown territory)
    * We tend to use Debian and Debian derivatives
    * root access is not required
    * No special user accounts are required
  1. MySQL server and client v5.0 or v5.1
    * Most Linux distributions come with MySQL pre-installed, but you can use your own binary (more about this in [Testing](http://code.google.com/p/maatkit/wiki/Testing))
    * If you want to test some very specific features, you may need to install the [Percona](http://www.percona.com/percona-lab.html) distribution of MySQL or another version of MySQL with the microslow patch applied
    * Maatkit testing using something similar to [MySQL Sandbox](https://launchpad.net/mysql-sandbox) does but you do not need to install MySQL Sandbox
  1. Subversion (svn)
    * This is not always pre-installed on Linux systems
    * On Debian systems, `sudo apt-get install subversion` to get/install it
  1. Perl
    * At least v5.8 is preferred, but we really don't pay much attention the Perl version (it's rarely been an issue)
  1. Perl Modules (see next section)
  1. prove
    * Should come with Perl
  1. diff
    * Should be standard on any sane system
  1. $EDITOR
    * An editor of your choice
    * We use vim, and love it
    * Eclipse (last time I checked) would not do all its magic without a Perl file extension (.pl or .pm) and none of the Maatkit tools have a file extension
    * Don't use an editor that uses ^M (some Windows editors)
  1. A Google account
    * Maatkit is hosted on Google Code
    * To submit bugs, participate in the mailing lists, or contribute code you need a Google account

There are other requirements that most developers won't need (like the rpm package on Debian boxes) so we don't list them here--they're listed where and when actually needed.

## Perl Modules ##

These Perl modules are used by various tools and test scripts:

  * Data::Dumper
  * DBD::mysql
  * DBI
  * Digest::MD5
  * File::Basename
  * File::Find
  * File::Spec
  * File::Temp
  * Getopt::Long
  * IO::Compress::Gzip
  * IO::File
  * IO::Uncompress::Inflate
  * List::Util
  * POSIX
  * Socket
  * Term::ReadKey
  * Test::More
  * threads
  * Thread::Queue
  * Time::HiRes
  * Time::Local

Most of those should be core modules.  If a tool needs a module that's not on your system, Perl will die saying which module it can't find.

Not all of those modules are needed to run the tools.  For example, threads is not needed to run mk-query-digest.  All modules are required only if you'll be [testing Maatkit](http://code.google.com/p/maatkit/wiki/Testing).

# 2. Request Commit Access #

If you plan to commit code (we hope you do!) then you need to ask for commit access either via the [discussion list](http://groups.google.com/group/maatkit-discuss) or ask us in #maatkit on Freenode IRC.

If you do not plan to commit code, you can still checkout a read-only copy of the trunk code.

# 3. Checkout Maatkit Code #

If you are not planning to contribute code (e.g. only to find bugs) you do not need to checkout Maatkit code from trunk but it may be very helpful to do so because released code is stripped of code comments that are only available from checkout trunk code.  It's easy to checkout a read-only copy of the code, so we suggest you do it.

Simply follow the instructions at http://code.google.com/p/maatkit/source/checkout.

As the previous section stated, you'll need commit access to checkout the code that you can later submit patches/fixes/updates back to.  Otherwise, you can only checkout a read-only copy of the code.

# Next Steps #

With the proper programs and the Maatkit code from trunk you're ready to begin development!  You should read [Code Overview](http://code.google.com/p/maatkit/wiki/CodeOverview) next.