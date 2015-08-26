#summary How to create a new Maatkit release

Follow these steps to make a new Maatkit release.  A lot of pre-release work must be done to insure a quality, bug-free release.

Since `svn lock` doesn't appear to be implemented (at least not with Google Code), try to ensure that no one else is committing stuff to trunk.

## 1. Check MustResolve Issues ##

Check for [MustResolve](http://code.google.com/p/maatkit/issues/list?q=label:MustResolve) issues, and resolve them or roll them back to a good state for the release.

## 2. Create a Release Issue ##

Create a new issue for the release, like [issue 1085](http://code.google.com/p/maatkit/issues/detail?id=1085).  Keep the same summary format for consistency, i.e. `Month YYYY release`.  Update this issue for commits related to the release (resulting from the following steps).

## 3. svn status ##

Check `svn status` from the trunk to make sure that there are no uncommitted changes or files not under svn control:

```
daniel@dante:~/dev/maatkit$ svn status
M      mk-duplicate-key-checker/mk-duplicate-key-checker
M      mk-query-digest/mk-query-digest
```

See?  I totally forgot that I needed to commit `mk-query-digest` and I have no idea why `mk-duplicate-key-checker` is modified.  So be sure to **start with a clean slate**.

## 4. Test Common Modules ##

The common modules (`trunk/common`) are the heart of all the tools so we test them first before updating them in all tools.

First get the Maatkit test environment up and running by following the [Maatkit testing wiki](http://code.google.com/p/maatkit/wiki/Testing).  The tests are supposed to work with or without the sandbox servers but currently some do not.

Second, test all the common modules:

```
cd trunk/common/t && prove
```

This should finish and give a summary like:

```
Failed Test       Stat Wstat Total Fail  List of Failed
-------------------------------------------------------------------------------
./LogSplitter.t    255 65280    20   38  2-20
./MasterSlave.t      2   512    34    2  16-17
./MySQLAdvisor.t   255 65280    11   20  2-11
./OptionParser.t    11  2816   141   11  46-47 51 53 89 91 94 102 104 116 119
./QueryParser.t    255 65280   127   20  118-127
./QueryReview.t    255 65280     6   10  2-6
./SlavePrefetch.t  255 65280    68   18  60-68
11 subtests skipped.
Failed 7/66 test scripts. 66/1663 subtests failed.
Files=66, Tests=1663, 75 wallclock secs (13.15 cusr +  2.33 csys = 15.48 CPU)
Failed 7/66 test programs. 66/1663 subtests failed.
```

Some of those are legitimate failures that we must fix, like `LogSplitter`, others are false-positives caused by `prove` being stupid, like `OptionParser`.  To be safe, manually run `perl <module>.t` for the false-positives.  You'll see that `perl OptionParser.t` passes everything.  These are the known false-positives and "acceptable" failures:

  * OptionParser: false-positive, verify with `perl OptionParser.t`

## 5. Review packages List ##

Review `trunk/maatkit/packages`.  We add, remove, retire, rename packages frequently enough that this should be checked.  This file is the master list of our published packages.  It is therefore also used by several tools; see the next step.

## 6. Update Common Modules ##

Ideally we want all common modules in all tools always up-to-date.  Sometimes this is not possible, but try really hard to make it possible.  This **keeps us out of code debt**.

In `trunk/maatkit/` run

```
for f in `cat packages`; do ./update-modules $f; done
```

For any production tools this signals a problem that should be resolved.  In this case I found out that:

```
daniel@dante:~/dev/maatkit/common$ svn log | grep AggregateProcesslist
Update package name AggregateProcesslist -> ProcesslistAggregator.
```

And if things are really borked, you may see an error that kills the tool like this:

```
ERROR: ../mk-loadavg/mk-loadavg has a malformed module header:
# Transformers package 4299 $Revision: 5210 $
```

Fix any malformed headers and re-run the script until all modules are proper and updated.  If you're paranoid and want to check that `update-modules` did its job ok (i.e. has no bugs), re-run that command and check that no modules are updated again.

## 7. Test Tools ##

After common modules have been updated in tools, test all the tools to make sure that the new modules have not broken things.  From step 2 the [Maatkit test environment](http://code.google.com/p/maatkit/wiki/Testing) should already be up and running.  (Hopefully you didn't skip step 2!)  The script `trunk/maatkit/test.sh` attempts to run `prove` for all tools, but currently all tests are not prove-friendly, so you may need to run each tool's test manually, like:

```
$ cd mk-archiver/t

$ perl mk-archiver.t

```

This is what I'm doing until all tests are prove-friendly.

At present the tests cannot be ran in parallel, but they should be able to be ran in any order.

**No tool tests should fail**.  There are no acceptable exceptions.  Take nothing for granted.  Do not underestimate the significance of tiny differences between expected and got values.  If a test is failing, figure out why and fix the _tool_, not the test.  If you deem it necessary to change/fix/alter a test, document why somewhere.  If you have to fix a common module, repeat this entire release process from step 1.

## 8. Light, Tight and Standardized ##

Use the following [developer utilities](http://code.google.com/p/maatkit/wiki/DeveloperUtilities) to ensure that the tools stay light, tight and standardized.

### 8.1 check-module-usage ###

Run `trunk/maatkit/check-module-usage` and review its output:

```
mk-loadavg has unused modules:
	WatchStatus
	WatchProcesslist
	WatchServer
mk-log-player has unused modules:
	QueryRewriter
mk-parallel-dump has unused modules:
	VersionParser
mk-query-digest has unused modules:
	TcpdumpParser
	MySQLProtocolParser
...
```

There will be false-positives for dynamically-loaded modules like the `Watch` modules in `mk-loadavg`, the parser modules in `mk-query-digest`, and the `TableSync` modules in `mk-table-sync`.

Look for strange stuff like `mk-parallel-dump` not using `VersionParser`.  I checked this and sure enough it does not use this module so I removed it.  I also checked and removed `QueryRewriter` from `mk-log-player` and `Quoter` and `VersionParser` from `mk-slave-move`.

This script does not read `trunk/maatkit/packages` so it may list non-published tools.

### 8.2 show-module-status ###

Run `trunk/maatkit/show-module-status` which basically does the same things as `update-modules` but without actually updating the modules.  This is a paranoid double-check on `updated-modules`.  The script should _not_ say that any modules are out of date.

### 8.3 check-pod ###

Run `trunk/maatkit/check-pod` to check all the tools' PODs.  At present, a few `mk-archiver` tests fail and `mk-query-digest` fails its "no long lines" test.  Everything else should be ok, so look for failed tests like:

```
not ok 52 - mk-schema-advisor: podchecker
#   Failed test 'mk-schema-advisor: podchecker'
#   at ./check-pod line 74.
#          got: '*** ERROR: unresolved internal link '--database' at line 3714 in file ../mk-schema-advisor/mk-schema-advisor
# *** ERROR: unresolved internal link '--fingerprint' at line 3921 in file ../mk-schema-advisor/mk-schema-advisor
# ../mk-schema-advisor/mk-schema-advisor has 2 pod syntax errors.
# '
#     expected: '../mk-schema-advisor/mk-schema-advisor pod syntax OK.
# '
```

`mk-schema-advisor` is not yet a published tool so I can ignore this.

There is one acceptable exception with `mk-archiver`:

```
not ok 1 - mk-archiver: podchecker
#   Failed test 'mk-archiver: podchecker'
#   at ./check-pod line 74.
#          got: '*** ERROR: unresolved internal link 'before_insert()' at line 5620 in file ../mk-archiver/mk-archiver
# *** ERROR: unresolved internal link 'before_bulk_insert()' at line 5635 in file ../mk-archiver/mk-archiver
# *** ERROR: unresolved internal link 'custom_sth()' at line 5638 in file ../mk-archiver/mk-archiver
# ../mk-archiver/mk-archiver has 3 pod syntax errors.
# '
#     expected: '../mk-archiver/mk-archiver pod syntax OK.
# '
```

### 8.4 alpha-options.pl ###

Run `trunk/maatkit/alpha-options.pl` to verify that the options are alphabetized in the POD.  Tools with options in subsections, like `mk-kill` and `mk-find` will report false positives because `alpha-options.pl` does not differentiate between `=head1` and `=head2` sections.

### 8.5 standardize-options ###

`trunk/maatkit/standardize-options` does not currently work very well because the standard opts don't have strictly standard descriptions.  Some descriptions say "the tool..." and others are more specific, saying "mk-kill ...".  You can run this check anyways, but the output is currently a lot of false-positives.

### 8.6 check-option-types ###

Run `trunk/maatkit/check-option-types`.  Everything should be OK.  If not, you should get a helpful and precise message about the problem, like:

```
not ok 37 - mk-visual-explain --charset has no short form but should have short form -A
#   Failed test 'mk-visual-explain --charset has no short form but should have short form -A'
#   at ./check-option-types line 145.
#          got: ''
#     expected: 'A'
```

In that case, as the message says, `--charset` in `mk-visual-explain` is supposed to have short form `-A` but it doesn't.

## 9. Update RISKS sections in PODs ##

The third section of every POD (after `NAME` and `SYNOPSIS`) should be `RISKS`.  Before each release all these sections have to be updated.

Look at the [issues tagged as a risk](http://code.google.com/p/maatkit/issues/list?can=2&q=Tag:risk&sort=tool&colspec=ID%20Type%20Tool%20Summary%20Tag), then edit/update the paragraph in the `RISKS` section for those tools that begins with "At the time of this release".  Only a high-level summary of a tool's risky issues needs to be mentioned.  For example:

```
At the time of this release, there is an unreproducible bug that causes a crash.
```

In general, this paragraph should be one long sentence, listing the risks in general terms.  You do not need to list specific issue numbers, details, etc.  A concerned user should follow the URL in the next paragraph (which you don't have to update; the rest of the `RISKS` section is a semi-fixed template).

## 10. Check Changelogs ##

The Changelogs should be updated as bugs are fixed, features added, etc., but sometimes I forget or tell myself I'll do it later (and then forget).  So it's best to think about what has changed and double-check the tools' Changelogs.

New tools (being published for the first time), will need a) a new Tool- entry in the issue tracker configuration, and b) a fresh Changelog like:

```
Changelog for mk-schema-advisor:

   * Initial release.
```

Existing tools' Changelog entries should follow these guidelines:

  * Each Changelog entry should fit on a single, 80 character column line and describe briefly what changed.
  * Bugs should be written in the past tense as the problem used to exist.  For example, "mk-foo did not fix the widget" rather than "mk-foo fixes the widget now."  This way it is clear what problems used to exist.
  * Indent each Changelog entry three spaces (watch out for tabs!)
  * Each release should have a one-liner with the date and version number.  The version numbers have to increase in sequence.  There's a check for this in the Makefile.

I do `vi mk-*/Changelog` from trunk and run through the files to jog my memory.

## 11. Bump Versions ##

Run `trunk/maatkit/bump-version --new` to update the version numbers in the Changelogs.  Then `svn commit` from trunk.

## 12. Build the Distros ##

Run the Makefile in `trunk/maatkit` to build all the distributions.

```
make all
```

This will call several scripts (like `package.pl`) which will,

  * Check for modified/uncommitted file
  * Check that each tool has the proper svn keywords (like `Revision`)
  * Check for other stuff we want to avoid
  * Update and commit `/trunk/maatkit/packlist`
  * Update and commit `	/trunk/maatkit/debian/changelog`
  * Build the four distros--a .tar.gz, a .zip, a .deb, and a .rpm

During the build process there is a known "error" that you can ignore:

```
+ debchange -D unstable -v 5014-1 'New upstream release.'
debchange warning: Recognised distributions are:
{warty,hoary,breezy,dapper,edgy,feisty,gutsy,hardy,intrepid,jaunty,karmic}{,-updates,-security,-proposed} and UNRELEASED.
Using your request anyway.
debchange: Did you see that warning?  Press RETURN to continue...
```

Press RETURN and make will continue.

If all goes well there will be no errors and you should get files like:

```
daniel@dante:~/dev/maatkit/maatkit$ ls release release-debian/ release-rpm/
release:
maatkit-5240.tar.gz  maatkit-5240.zip

release-debian/:
maatkit_5240-1_all.deb        maatkit_5240-1.dsc
maatkit_5240-1_amd64.build    maatkit_5240-1_source.build
maatkit_5240-1_amd64.changes  maatkit_5240-1_source.changes
maatkit_5240-1.diff.gz        maatkit_5240.orig.tar.gz

release-rpm/:
BUILD  maatkit-5240-1.noarch.rpm  RPMS  SOURCES  SPECS  SRPMS
```

## 13. Upload Distros to Google Code ##

Upload the distros created in the last step to Google Code by running `upload GC_USERNAME` where `GC_USERNAME` is your Google Code username.  This is going to prompt you four times--once for each package--for your Google Code password.  Your Google Code password is available via `Profile -> Settings tab`.

```
daniel@dante:~/dev/maatkit/maatkit$ ./upload gc_user@example.com
Please enter your googlecode.com password.
** Note that this is NOT your Gmail account password! **
It is the password you use to access Subversion repositories,
and can be found here: http://code.google.com/hosting/settings
Password:
The file was uploaded successfully.
```

Once done, unset the Featured labels for the previous release at http://code.google.com/p/maatkit/downloads/list.  This is done by clicking a previous release in the list anywhere except on its name to access its labels.

## 14. Update maatkit.org ##

You'll need access to maatkit.org to do this.  Currently only Baron and Daniel have access.

ssh to maatkit.org and update the docs and downloads by running:

```
cd /usr/home/pl981/public_html/maatkit.org/get/trunk
/usr/local/bin/svn -q up
/usr/local/bin/svn -q up -r`/usr/bin/grep Revision maatkit/packlist | /usr/bin/awk '{print $2}'` mk-*
cd ../../trunk/trunk
svn up
cd ../../doc/
./make.sh
cd ../latest/
./update-latest-rel.sh
```

The `make.sh` command spews a whole bunch of crap.  Hopefully it just keeps working forever because we've kind of forgotten how it works.  :-)

For good measure, check some docs at http://www.maatkit.org/doc/ and make sure they look current (i.e. look for something you know is new in the release).  If they don't look correct, find out what went wrong and fix it.

## 15. Copy trunk/ to releases/ ##

A snapshot of the trunk is branched/copied to the releases/ directory to keep a historical record of the code base at each release.  Execute:

```
svn copy https://maatkit.googlecode.com/svn/trunk https://maatkit.googlecode.com/svn/releases/YYYY-MM
```

Replace `YYYY-MM` with the release's year and month; e.g.: `2010-07`.  That command will start your editor; enter a commit message like:

```
Update issue N
Copy trunk to releases/YYYY-MM.
```

Replace `N` with the release issue created in step 2.

trunk has to be copied last because the build process does commits (e.g. when it updates `packlist`) which changes the revisions number and currently the scripts that update the docs on maatkit.org are sensitive to the revno.  If you copy trunk then build, updating the maatkit.org docs will fetch the wrong release and mix up the revnos in the docs that it generates.

## 16. Release Announcement ##

Send a release announcement to the list, http://groups.google.com/group/maatkit-discuss.  Entitle the post, "Maatkit version N released", where N is the new release revision.  Use `trunk/maatkit/latest-changelog` to make a list of changes for this release.  Include this at the end of your announcement.

Then add the release announcement to the [ReleaseNotes](http://code.google.com/p/maatkit/wiki/ReleaseNotes) wiki.  See previous releases for conventions.

## 17. Notify Distro Maintainers ##

### 17.1 Debian ###

Send an email to `submit@bugs.debian.org`, Cc Baron, Daniel and Dario (midget at debian dot org), with subject `maatkit: new release N for MONTH YYYY` (replacing `MONTH` with "February", etc.), and with body:
```
Package: maatkit
Severity: wishlist

A new version of Maatkit has been released: N.  This bug report is to notify maintainers of its availability.

Release notes and a complete changelog are available at RELEASE-NOTES-URL

Versions of packages maatkit depends on:
ii  libdbd-mysql-perl     4.008-1            A Perl5 database interface to the
ii  libdbi-perl           1.607-1            Perl5 database interface by Tim Bu
ii  libterm-readkey-perl  2.30-4             A perl module for simple terminal
ii  perl                  5.10.0-19ubuntu1.1 Larry Wall's Practical Extraction

maatkit recommends no packages.

maatkit suggests no packages.
```
Replace `RELEASE-NOTES-URL` with the URL created by step 16 above.

(This is from [issue 1059](https://code.google.com/p/maatkit/issues/detail?id=1059).)

### 17.2 ###

Notify Vadim's packaging team at Percona so that they can update in the Percona repositories.

## 18. Done ##

You're done!  And if you're lucky, no one immediately discovers a nasty bug in your new release.