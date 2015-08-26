#summary Internal mechanics of Transformers.pm

# Synopsis #

The common module Transformers.pm is a collection of little subroutines which transform their input from one format to another. For example, `secs_to_time()` transforms a number of seconds to a string of "days hours:minutes:seconds".

Transformers is a unique because it is currently the only module that is not a class/blessed object. Instead, Transformers uses [Exporter](http://perldoc.perl.org/Exporter.html) to export whatever subroutines you select into the namespace of the calling package.

Therefore, you do not `use Transformers;` in a tool, you `import`:
```
Transformers->import(qw(shorten micro_t percentage_of ts make_checksum));
```

Then simply call the imported subroutines in the tool; no `package::` qualification is needed.