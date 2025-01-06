#- initializations -------------------------------------------------------------
use Identity::Utils:ver<0.0.16+>:auth<zef:lizmat> <bytecode>;
use MoarVM::Bytecode:ver<0.0.22+>:auth<zef:lizmat>;

# The root to be applied to SETTING:: prefixes
my $SETTING-root = $*EXECUTABLE.parent(3);

my %repo-name2root = $*REPO.repo-chain.map: -> $repo {
    with try $repo.name {
        $_ => $repo.prefix
    }
    orwith try $repo.id {
        $_ => ""
    }
}

#- class -----------------------------------------------------------------------
class Code::Coverable {
    has str $.target     is required;            # target used to get coverables
    has     @.line-numbers is required is List;  # lines that could be covered
    has str $.key = $!target;                    # key to check in coverage log
    has IO::Path $.source;                       # associated source IO if any

    method source(Code::Coverable:D:) {
        with $!source {
            $_
        }
        else {
            my $target := $!key.subst(/ ' (' .* /);
            my ($repo-name,$postfix) = $target.split("#",2);
            with $postfix && %repo-name2root{$repo-name} {
                $!source := .add($postfix);
            }
            elsif $target.starts-with("SETTING::") {
                $!source := $SETTING-root.add($target,substr(9));
            }
            elsif $target.starts-with("/") {
                $!source := $target.IO;
            }
        }
    }
}

#- subroutines -----------------------------------------------------------------
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
    with bytecode($identity, $repo) andthen MoarVM::Bytecode.new($_) {
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

my proto sub coverables(|) is export {*}

my multi sub coverables(*@paths, :$repo) {
    coverables(@paths, :$repo)
}
my multi sub coverables(@paths, :$repo) {
    @paths.map: -> $target {
        with bytecode($target, $repo) andthen MoarVM::Bytecode.new($_) {
            .coverables.map( {
                Code::Coverable.new(
                  target       => $target,
                  key          => .key,
                  line-numbers => .value.List
                )
            }).Slip
        }
        else {
            my $io := $target.IO;
            if $io.e {
                Code::Coverable.new(
                  target       => $io.absolute,
                  line-numbers => .List,
                  source       => $io
                ) with coverable-lines($io)
            }
        }
    }
}

=begin pod

=head1 NAME

Code::Coverable - Produce overview of coverable lines of code

=head1 SYNOPSIS

=begin code :lang<raku>

use Code::Coverable;

say coverable-lines($path.IO);  # (3 5 11 24)

say coverable-lines($source);   # (7 9 23 25)

my @coverables = coverables(@paths);

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

=head2 coverables

=begin code :lang<raku>

for coverables(@targets) -> $cc {
    say $cc.target;
    say $cc.key;
    say $cc.line-numbers;
    say $cc.source;
}

=end code

The C<coverables> subroutine takes any number of positional
arguments, each of which is assumed to be a target specification,
which can be:
=item a C<Str> specification of a Raku source file
=item an C<IO::Path> object specifying a Raku source file
=item a distribution identity (such as "Foo::Bar:ver<0.0.2>")

It returns a C<Seq> of C<Code::Coverable> objects.  Note that it
B<is> possible that even a single target produces more than one
C<Code::Coverable> object, if the source of the target has used
C<#line 42 filename> directives.

=begin code :lang<raku>

for coverables("String::Utils", :repo<.>) -> $cc {
    say $cc.target;
    say $cc.key;
    say $cc.line-numbers;
    say $cc.source;
}

=end code

If distribution identities are specified, a C<:repo> named argument
can be specified, which can be an object of type:
=item Str - indicate a path for a ::FileSystem repo, just as with -I.
=item IO::Path - indicate a path for a ::FileSystem repo
=item CompUnit::Repository - the actual repo to use

The default is to use the current C<$*REPO> setting to resolve any
identity given.

=head1 CLASSES

=head2 Code::Coverable

The C<Code::Coverable> object is generally created by the C<coverables>
subroutine, but could also be created manually.

=begin code :lang<raku>

my $cc = Code::Coverable.new(
  target       => "Identity::Utils",
  key          => "site#sources/072CEA63F659CFD963095494CEA22A46E4F93A95 (Identity::Utils)"
  line-numbers => (1,14,19,...),
  source         => "/.../site/sources/072CEA63F659CFD963095494CEA22A46E4F93A95".IO,
);

=end code

The following public attributes are available:

=head3 target

Mandatory: a string with the target for these coverables: this can
either be distribution name, or a path to a source file.

=head3 key

Mandatory: a string that should match in the coverage log to mark
a line as being "covered".

=head3 line-numbers

Mandatory: a C<List> of unique integer values of the line numbers
that B<could> potentially be covered in a coverage log.

=head3 source

Optional: an C<IO::Path> object of the Raku source file.  This
could either be the same as the target, or could be derived from
the information specified for the key.

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

Source can be located at: https://github.com/lizmat/Code-Coverable . Comments and
Pull Requests are welcome.

If you like this module, or what I'm doing more generally, committing to a
L<small sponsorship|https://github.com/sponsors/lizmat/>  would mean a great
deal to me!

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
