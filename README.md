NAME
====

Code::Coverable - Produce overview of coverable lines of code

SYNOPSIS
========

```raku
use Code::Coverable;

say coverable-lines($path.IO);  # (3 5 11 24)

say coverable-lines($source);   # (7 9 23 25)
```

DESCRIPTION
===========

Code::Coverable contains logic for producing code coverage reports.

This is still a work in progress. At the moment it will only export two subroutines and install a script "coverage-lines".

SUBROUTINES
===========

coverable-lines
---------------

```raku
say coverable-lines($path.IO);  # (3 5 11 24)

say coverable-lines($source);   # (7 9 23 25)
```

The `coverable-lines` subroutine takes a single argument which is either a `IO::Path` or a `Str`, uses its contents (slurped in case of an `IO::Path`), tries to build an AST from that and returns a sorted list of line numbers that appear to have coverable code.

coverable-files
---------------

```raku
say coverable-files(@paths); # Map.new(path => lines)
```

The `coverable-files` subroutine takes any number of positional arguments, each of which is assumed to be a path specification of a Raku source file (or an `IO::Path` object). It returns a `Map` with the path names as keys, and an ordered list of line numbers as the values.

SCRIPTS
=======

coverage-lines
==============

    $ coverable-lines t/01-basic.rakutest 
    t/01-basic.rakutest: 1,3,5,7,8,9,10,13,14,15,16,17

The `coverable-lines` script accepts any number of paths and will attempt to produce one line of output for each path, and the line numbers of the lines that may appear in a coverage report.

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

COPYRIGHT AND LICENSE
=====================

Copyright 2024 Elizabeth Mattijsen

Source can be located at: https://github.com/lizmat/actions . Comments and Pull Requests are welcome.

If you like this module, or what I'm doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

