use MoarVM::Bytecode:ver<0.0.21+>:auth<zef:lizmat>;

my proto sub coverable-lines(|) is export {*}

my multi sub coverable-lines(IO:D $io) {
    coverable-lines($_) with $io.slurp;
}

my multi sub coverable-lines(Str:D $string, $repo?) {
    $string.contains("\n")
      ?? coverables-from-source($string)
      !! coverables-from-bytecode($string, $repo)
}

my sub coverables-from-bytecode(Str:D $identity, $repo) {
    with try MoarVM::Bytecode.new($identity, $repo) {
        my $coverables := .coverables;
        return $coverables.values.head if $coverables.keys == 1;
    }

    ()
}

my sub coverables-from-source(Str:D $source) {
    my int @lines;
    sub get-line($node) {
        unless $node.^name.starts-with('RakuAST::Doc') {
            @lines.push(.source.original-line(.from))
              with $node.origin;
            $node.visit-children(&get-line);
        }
    }
    with $source.AST {
        .visit-children: &get-line;
        @lines.sort.squish.List
    }
}

my proto sub coverable-files(|) is export {*}

my multi sub coverable-files(*@paths, :$repo) {
    coverable-files(@paths, $repo)
}
my multi sub coverable-files(@paths, :$repo) {
    @paths.map(-> $path {
        my $io := $path.IO;
        if $io.e {
            $io.absolute => $_ with coverable-lines($io)
        }
        orwith MoarVM::Bytecode.new($path, $repo) {
            .coverables.Slip
        }
    }).Map
}

=begin pod

=head1 NAME

Code::Coverable - Produce overview of coverable lines of code

=head1 SYNOPSIS

=begin code :lang<raku>

use Code::Coverable;

say coverable-lines($path.IO);  # (3 5 11 24)

say coverable-lines($source);   # (7 9 23 25)

say coverable-files(@paths); # Map.new(path => lines, ...)

=end code

=head1 DESCRIPTION

Code::Coverable contains logic for producing code coverage reports.

This is still a work in progress.  At the moment it will only export two
subroutines and install a script "coverage-lines".

=head1 SUBROUTINES

=head2 coverable-lines

=begin code :lang<raku>

say coverable-lines($path.IO);  # (3 5 11 24)

say coverable-lines($source);   # (7 9 23 25)

=end code

The C<coverable-lines> subroutine takes a single argument which is
either a C<IO::Path> or a C<Str>, uses its contents (slurped in case
of an C<IO::Path>), tries to build an AST from that and returns
a sorted list of line numbers that appear to have coverable code.

=head2 coverable-files

=begin code :lang<raku>

say coverable-files(@paths);           # Map.new(path => lines, ...)

say coverable-files(@paths, :repo<.>); # Map.new(path => lines, ...)

=end code

The C<coverable-files> subroutine takes any number of positional
arguments, each of which is assumed to be a path specification of a
Raku source file (or an C<IO::Path> object), or a distribution
identity (such as "Foo::Bar:ver<0.0.2>").

It returns a C<Map> with the absolute paths as keys, and an ordered
list of line numbers as the values.

If distribution identities are specified, a C<:repo> named argument
can be specified, which can be an object of type:
=item Str - indicate a path for a ::FileSystem repo, just as with -I.
=item IO::Path - indicate a path for a ::FileSystem repo
=item CompUnit::Repository - the actual repo to use

The default is to use the current $*REPO setting to resolve any
identity given.

=head1 SCRIPTS

=head2 coverable-lines

=begin output

$ coverable-lines t/01-basic.rakutest 
t/01-basic.rakutest: 1,3,5,7,8,9,10,13,14,15,16,17

=end output

The C<coverable-lines> script accepts any number of paths and will
attempt to produce one line of output for each (absolute) path, and
the line numbers of the lines that may appear in a coverage report.

=head1 AUTHOR

Elizabeth Mattijsen <liz@raku.rocks>

=head1 COPYRIGHT AND LICENSE

Copyright 2024, 2025 Elizabeth Mattijsen

Source can be located at: https://github.com/lizmat/actions . Comments and
Pull Requests are welcome.

If you like this module, or what I'm doing more generally, committing to a
L<small sponsorship|https://github.com/sponsors/lizmat/>  would mean a great
deal to me!

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
