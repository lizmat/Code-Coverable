[![Actions Status](https://github.com/lizmat/Code-Coverable/actions/workflows/linux.yml/badge.svg)](https://github.com/lizmat/Code-Coverable/actions) [![Actions Status](https://github.com/lizmat/Code-Coverable/actions/workflows/macos.yml/badge.svg)](https://github.com/lizmat/Code-Coverable/actions) [![Actions Status](https://github.com/lizmat/Code-Coverable/actions/workflows/windows.yml/badge.svg)](https://github.com/lizmat/Code-Coverable/actions)

NAME
====

Code::Coverable - Produce overview of coverable lines of code

SYNOPSIS
========

```raku
use Code::Coverable;

say coverable-lines($path.IO);  # (3 5 11 24)

say coverable-lines($source);   # (7 9 23 25)

my @coverables = coverables(@paths);
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

coverables
----------

```raku
for coverables(@targets) -> $cc {
    say $cc.target;
    say $cc.key;
    say $cc.line-numbers;
    say $cc.source;
}
```

The `coverables` subroutine takes any number of positional arguments, each of which is assumed to be a target specification, which can be:

  * a `Str` specification of a Raku source file

  * an `IO::Path` object specifying a Raku source file

  * a distribution identity (such as "Foo::Bar:ver<0.0.2>")

It returns a `Seq` of `Code::Coverable` objects. Note that it **is** possible that even a single target produces more than one `Code::Coverable` object, if the source of the target has used `#line 42 filename` directives.

```raku
for coverables("String::Utils", :repo<.>) -> $cc {
    say $cc.target;
    say $cc.key;
    say $cc.line-numbers;
    say $cc.source;
}
```

If distribution identities are specified, a `:repo` named argument can be specified, which can be an object of type:

  * Str - indicate a path for a ::FileSystem repo, just as with -I.

  * IO::Path - indicate a path for a ::FileSystem repo

  * CompUnit::Repository - the actual repo to use

The default is to use the current `$*REPO` setting to resolve any identity given.

CLASSES
=======

Code::Coverable
---------------

The `Code::Coverable` object is generally created by the `coverables` subroutine, but could also be created manually.

```raku
my $cc = Code::Coverable.new(
  target       => "Identity::Utils",
  key          => "site#sources/072CEA63F659CFD963095494CEA22A46E4F93A95 (Identity::Utils)"
  line-numbers => (1,14,19,...),
  source         => "/.../site/sources/072CEA63F659CFD963095494CEA22A46E4F93A95".IO,
);
```

The following public attributes are available:

### target

Mandatory: a string with the target for these coverables: this can either be distribution name, or a path to a source file.

### key

Mandatory: a string that should match in the coverage log to mark a line as being "covered".

### line-numbers

Mandatory: a `List` of unique integer values of the line numbers that **could** potentially be covered in a coverage log.

### source

Optional: an `IO::Path` object of the Raku source file. This could either be the same as the target, or could be derived from the information specified for the key.

SCRIPTS
=======

coverable-lines
---------------

    $ coverable-lines t/01-basic.rakutest 
    t/01-basic.rakutest: 1,3,5,7,8,9,10,13,14,15,16,17

The `coverable-lines` script accepts any number of paths and will attempt to produce one line of output for each (absolute) path, and the line numbers of the lines that may appear in a coverage report.

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

COPYRIGHT AND LICENSE
=====================

Copyright 2024, 2025 Elizabeth Mattijsen

Source can be located at: https://github.com/lizmat/Code-Coverable . Comments and Pull Requests are welcome.

If you like this module, or what I'm doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

