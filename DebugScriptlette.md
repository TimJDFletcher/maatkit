#summary Purpose and use of the _d.pl scriptlette_

# Introduction #

As per [issue 120](https://code.google.com/p/maatkit/issues/detail?id=120), the `_`d() debug subroutine found in every tool and common module has been standardized. Because common modules cannot have dependencies with other modules, no Debug common was created. Instead, `_`d.pl contains the `_`d() sub that must be manually copied into every tool and module.

# Copying the Standard `_`d() Sub #

The only thing in common/`_`d.pl is the `_`d() subroutine. It should not even contain the shebang (#!) line. Therefore, at the end of every module and tool (before 1; for modules or the POD for tools), the standard `_`d() sub can be read in by using the following vi command:
```
   :r ../common/_d.pl
```
Of course, you'll need to adjust the path to `_`d.pl.

# Testing `_`d() #

Even thought it is not, technically speaking, a common module, `_`d.pl has a test script: `_`d.t. This test script reads in `_`d.pl and evals the `_`d() sub into its own main namespace so that it can be tested because `_`d.pl is only a "scriptlette" (that is, a single sub is not really a full script).