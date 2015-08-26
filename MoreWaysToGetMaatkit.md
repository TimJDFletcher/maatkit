# Introduction #

Each release has several flavors of files:

  * Source distributions (zipped and tarballed, with installation instructions included)
  * An RPM for Red Hat and derivative systems
  * A Debian/Ubuntu package file

But there are many other ways to get Maatkit.

## Downloading Directly ##

You don't need to install Maatkit tools to run them.  You can just download them and run them with no further ado.

You can get the latest release of any tool without the need to get the whole kit:

```
wget http://www.maatkit.org/get/toolname
```

Where "toolname" is the name, or fragment thereof, of any tool such as mk-table-checksum.

You can also get the latest committed SVN code in a similar way:

```
wget http://www.maatkit.org/trunk/toolname
```

## From Your OS Distribution ##

A lot of OSes are including Maatkit these days.  It's part of the standard MySQL client install on Debian, for example; and it's included in many other popular GNU/Linux distributions, as well as FreeBSD and OpenBSD.

Of course it might not be the latest release.

## Alternate Package Locations ##

Third parties build packages of Maatkit releases and make them available through various places.

  * http://mirror.provenscaling.com/yum/extras/i386/xaprb/
  * http://software.opensuse.org/search?q=maatkit

If you want another location added to this list, enter a new issue report.

## Building RPMs ##

Maatkit's source tarball has a .spec file included, which works for many RPM-based distributions.  You can also write your own (please contribute it if you do?).  To build an RPM from a source tarball using the included .spec file, just run

```
rpmbuild -ta maatkit-123.tar.gz
```

To build an RPM with your own spec file, you need to copy the spec file into the RPM SPECS directory, and a maatkit source tarball into the RPM SOURCES directory. Then you run

```
rpmbuild -ba --clean maatkit.spec
```

And it should perform the building and packaging. Unfortunately the resulting RPM is again distro-specific (particularly because of the Perl version).

(Thanks to LenZ for these instructions.)

There are more spec files in the [trunk/spec/](http://code.google.com/p/maatkit/source/browse/trunk/spec) directory in Maatkit's Subversion repository.

## Using From a USB Key ##

It's possible to run Maatkit even without Perl installed.  See http://blog.thetajoin.com/content/portable-maatkit for a tutorial on creating a USB thumb drive that will let you run Maatkit from any computer.