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
my multi sub coverables(@targets, :$repo) {
    @targets.map: -> $target {
        with bytecode($target, $repo) andthen MoarVM::Bytecode.new($_) {
            .coverables.map( {
                my @line-numbers := .value;
                @line-numbers.shift if @line-numbers.head == 1;

                Code::Coverable.new(
                  target       => $target,
                  key          => .key,
                  line-numbers => @line-numbers.List,
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

# vim: expandtab shiftwidth=4
