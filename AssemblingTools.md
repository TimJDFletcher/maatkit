#summary How to work with modules and packaging in the tools

# Introduction #

Modules from trunk/common/ are copy-pasted right into the tools so no modules are necessary to run them.  Redundant code is much less of an issue than the ability to just run the tool.  (This also lets us keep different versions of a module so we don't have to update every single tool when there is a breaking change).

A tool that has modules embedded can be manipulated from within the trunk/maatkit/ subdirectory.  The update-modules and insert\_module scripts do this.  For example,

```
baron@kanga:~/etc/maatkit/trunk/maatkit$ ./update-modules mk-archiver
Updating DSNParser in ../mk-archiver/mk-archiver
Updating MySQLDump in ../mk-archiver/mk-archiver
```

A quick one-liner:

```
for f in `ls ../ | grep mk-`; do ./update-modules $f; done
```

The update-modules script also takes an optional second argument, which is the name of the module to update.

From within vim, you can update the module embedded in the code you're working on:

```
:%!../maatkit/insert_module DSNParser
```

# Module requirements #

For this to work, modules in common/ must follow some conventions:

  * The header and footer have to exist.
  * The file has to have the SVN keyword set.

The keyword is as follows:

```
baron@kanga:~/etc/maatkit/trunk/common$ svn proplist DSNParser.pm 
Properties on 'DSNParser.pm':
  svn:keywords
baron@kanga:~/etc/maatkit/trunk/common$ svn propget svn:keywords DSNParser.pm 
Revision
```

You can set this like so:

```
baron@kanga:~/etc/maatkit/trunk/common$ svn propset svn:keywords Revision DSNParser.pm 
property 'svn:keywords' set on 'DSNParser.pm'
```

Next, you have to have the header and footer, like this:

```
# ###########################################################################
# DSNParser package $Revision: $
# ###########################################################################
```

Make sure you get the right number of # marks in the two long lines, or the tool won't be auto-updatable.

The only thing I put above this header is the copyright notice.

Footer (also must have the right number of # marks):

```
# ###########################################################################
# End DSNParser package
# ###########################################################################
```

With this magic in place, DSNParser is ready to be embedded.

# In the Tool #

In the tool where you want to include the DSNParser module, place your cursor in Vim and type:

```
:r ../common/DSNParser.pm
```

And then delete the copyright notice.  Now you will have to change the header line to remove the $dollar signs (because we don't want SVN auto-updating the revision -- we want to see which revision of each module is embedded in the tool).

You should end up with this comment in the tool file:

```
# ###########################################################################
# DSNParser package 2005
# ###########################################################################
```

Now this tool is auto-updatable by the magic of update-modules and insert\_module.

# Validation and Testing #

You can validate your embedded modules and test them for up-to-dateness with the following script:

```
trunk/maatkit/show-module-status
```

It will check for malformed module headers and some other things, too.