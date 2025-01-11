#- initializations -------------------------------------------------------------
use Identity::Utils:ver<0.0.17+>:auth<zef:lizmat> <bytecode source>;
use MoarVM::Bytecode:ver<0.0.24+>:auth<zef:lizmat>;

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
    has str $.target       is required;          # target used to get coverables
    has     @.line-numbers is required is List;  # lines that could be covered
    has str $.key = $!target;                    # key to check in coverage log
    has IO::Path $.source;                       # associated source IO if any

    method source(Code::Coverable:D:) {
        with $!source {
            $_
        }
        orwith key2source($!key) {
            $!source := $_;
        }
    }
}

#- coverable-lines -------------------------------------------------------------
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

#- coverables ------------------------------------------------------------------
my proto sub coverables(|) is export {*}

my multi sub coverables(*@targets, :$repo) {
    coverables(@targets, :$repo)
}
my multi sub coverables(@targets, :$repo, :$raw) {
    @targets.map: -> $target {
        with bytecode($target, $repo) andthen MoarVM::Bytecode.new($_) {
            .coverables.map( {
                my $line-numbers := .value;

                # heuristics weeding out lines that will never be covered
                $line-numbers := weed-out($target, $repo, $line-numbers)
                  unless $raw;

                Code::Coverable.new(
                  :$target, :key(.key), :line-numbers($line-numbers.List)
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

#- key2source ------------------------------------------------------------------
my sub key2source($key) is export {
    my $target := $key.subst(/ ' (' .* /);
    my ($repo-name,$postfix) = $target.split("#",2);
    with $postfix && %repo-name2root{$repo-name} {
        .add($postfix)
    }
    elsif $target.starts-with("SETTING::") {
        $SETTING-root.add($target,substr(9))
    }
    elsif $target.starts-with("/") {
        $target.IO
    }
    else {
        Nil
    }
}

#- weed-out --------------------------------------------------------------------
# The logic behind this weeding out, is to prevent false positives in
# any coverage report.  There appear to be a number of cases in MoarVM
# when a line in source is marked as "coverable", but then is *not*
# marked as covered, even though clearly the line got executed from the
# surrounding lines getting marked as executed.  By unmarking these
# lines here, the risk of false positives is reduced.  Should lines
# be marked as covered even if they were not marked as coverable, then
# they will simply show up in coverage reports as ✱ vs. *.

my sub weed-out($target, $repo, @line-numbers) {
    my @lines     = source($target, $repo).lines;
    @lines.unshift("");  # allow 1-based indexing

    my $accepted := IterationBuffer.new;
    while @line-numbers {
        my $line-number := @line-numbers.shift;
        my $line        := @lines[$line-number];

        # "else" statements never get covered
        if $line ~~ /^
          \s+ else \s+ '{'
        / { }

        # Variable initializations rarely get covered, only if they happen
        # to have a complicated expression on the RHS.  In which case they
        # *will* get covered anyway, and just show up as covered anyway.
        elsif $line ~~ /^
          \s* [my | has | our] [\s+ <[-_:\w]>+]? \s+ <[$@%&]> <[.!*]>? <[-_\w]>+
        / { }

        # A line with just an identifier without ; at the end of a scope
        # is very likely to not get covered.
        elsif $line ~~ /^ \s+ <[$@%&]>? <[-_\w]>+ $/
          && (@lines[$line-number + 1] // "") ~~ /^ \s* '}' $/ { }

        # Use statements are compile-time, and thus never covered
        elsif $line ~~ /^ \s* use \s+ / { }

        # Constants and enums are compile-time, and thus never covered
        elsif $line ~~ /^ \s* [ my | our ] \s+ [constant | enum] \s+ / { }

        # Protos are almost never covered
        elsif $line ~~ /^ \s* [[my | our] \s+]?  proto \s+ / { }

        # Lines for just opening scope
        elsif $line ~~ /^ \s* [[')' | ']'] \s+]?'{' [\s+ '}']? $/ { }

        # Lines that finalize a signature, are almost never covered
        elsif $line ~~ /^ \s* '-->' / && $line.ends-with('{') { }

        # Lines that start with an nqp::op are almost never covered
        elsif $line ~~ /^ \s* 'nqp::' <[-\w]>+ '('? / { }

        # Lines that are marked as uncoverable
        elsif $line.ends-with('# UNCOVERABLE') { }

        # No reason to not include this line as coverable
        else { $accepted.push: $line-number }
    }

    $accepted
}

# vim: expandtab shiftwidth=4
