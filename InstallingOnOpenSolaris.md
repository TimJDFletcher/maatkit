From a bare-bones install, here's what's needed to install on OpenSolaris:

# For Maatkit Users #

The install utility is called `pkg` and you can search for packages with `pkg search` and then install with `pkg install`.  It doesn't seem to know about dependencies -- it will install DBD::mysql without installing DBI.

```
# DBI
pkg install pkg:/SUNWpmdbi
# DBD::mysql
pkg install pkg:/SUNWapu13dbd-mysql
```

# For Maatkit Developers #

```
# subversion
pkg install pkg:/SUNWsvn
# mysql
pkg install pkg:/SUNWmysql5
```

The "mysql" binary installed is in /usr/sfw/bin/mysql (or /usr/mysql/5.0/bin/mysql) which is not in the default path.  You can start MySQL with

```
# svcadm -v enable mysql
svc:/application/database/mysql:version_50 enabled.
# svcs -a | grep mysql
online          3:49:01 svc:/application/database/mysql:version_50
```

And prove is probably at `/usr/perl5/5.8.4/bin/prove`, also not in the default path.

To install CPAN modules, like Test::More, run `perl -MCPAN -e shell`, configure it when it prompts you to (most default values should be ok), then `install Test::More` or whatever module you want.  Here's a related link: http://slashzeroconf.wordpress.com/2008/02/17/installing-perl-modules-in-solaris/.