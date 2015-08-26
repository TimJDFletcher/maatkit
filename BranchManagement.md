Unlike other version control systems, branches in svn are just copies of directories with a shared history.  And since the Maatkit code base is over 100M large, the following advice can help developers management Maatkit branches more easily and avoid pitfalls with svn.  This requires svn v1.5 or newer, which should be the norm.

# Working Copies #

Previous wikis mentioned trunk verses branches.  Mostly they just dealt with trunk because Maatkit developers used to commit only to trunk and there were no branches, but now we commit to both trunk and different branches which means that each developer on his local machine can multiple working copies of the Maatkit code base.

Multiple working copies creates two problems.  First, branch checkouts are expensive because the Maatkit code base is over 100M large.  Second, each working copy has to be independently testable, so changes in a branch have to be tested with only the branch's code and not trunk code.  The first problem is solved with `svn switch`, and the second problem is solved by `MAATKIT_WORKING_COPY`.

# Directory Structure for Developers #

The first thing a developer should do is create an ideal directory structure.  On my box I have:

```
~/dev/maatkit$ ls
releases  trunk  working-copy
```

The root directory, `~/dev/maatkit`, is not under svn control; it just keeps Maatkit-related code together.  The three directories, `releases`, `trunk` and `working-copy` are svn directories, checked out with the following commands:

```
svn checkout https://maatkit.googlecode.com/svn/releases releases --username ...
svn checkout https://maatkit.googlecode.com/svn/trunk trunk --username ...
svn checkout https://maatkit.googlecode.com/svn/branches/mk-variable-advisor working-copy --username ...
```

The `releases` directory is only for people who do releases, which is currently only me and Baron so we'll ignore this directory.  The `trunk` directory is familiar so we'll skip it, too.  What's important is `working-copy` which is actually a checkout of the `mk-variable-advisor` branch.  `working-copy` is actually a generic directory that can be pointed to any branch by using `svn switch`.  Instead of doing a checkout for every branch, which requires downloading the 100M+ code base each time, `svn switch` will changes only what needs to be changed. Therefore, with `trunk` and a working copy directory for branches, developers should have all they need.  The working copy dir could be pointed to trunk, too, but since trunk is special, we give it its own directory.

# svn switch #

The following command will switch the local `working-copy` directory to a new branch:

```
svn switch https://maatkit.googlecode.com/svn/branches/new-branch
```

Before you switch your local working copy dir, be sure that there are no uncommitted changes to the current branch, else they will be lost!  You can see which branch the dir points to by doing:

```
$ svn info 
Path: .
URL: https://maatkit.googlecode.com/svn/branches/mk-variable-advisor
...
```

The second lines shows that my working copy is pointing to the `mk-variable-advisor` branch.  Any changes/commits I do inside this dir will update that branch.

# `MAATKIT_WORKING_COPY` #

Since there are multiple local copies of the code base, the one that is used for testing is the one pointed to by the `MAATKIT_WORKING_COPY` environment variables.  On my system, I usually kept this set to my local copy of trunk, but when I work on a branch I do something like:

```
$ cd working-copy/
$ export MAATKIT_WORKING_COPY=`pwd`
$ env | grep MAATKIT_WORKING_COPY
MAATKIT_WORKING_COPY=/home/daniel/dev/maatkit/working-copy
```

I do this in each terminal that I use for working on that branch (I usually have 2: one for work on the code, another for working on its tests).

Be sure `MAATKIT_WORKING_COPY` is pointing to the directory you're working in, else tests ran in the local directory will actually read and execute files in whatever directory `MAATKIT_WORKING_COPY` points to.  This happens because tests are path-independent, relying completely on `MAATKIT_WORKING_COPY` to tell them where they're located, so to speak.

# Next Steps #

That's it for testing related stuff.  Next are [Coding Standards](http://code.google.com/p/maatkit/wiki/CodingStandards).