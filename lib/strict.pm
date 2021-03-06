package strict;

$strict::VERSION = "1.10c";

# Verify that we're called correctly so that strictures will work.
unless ( __FILE__ =~ /(^|[\/\\])\Q${\__PACKAGE__}\E\.pmc?$/ ) {
    # Can't use Carp, since Carp uses us!
    my (undef, $f, $l) = caller;
    die("Incorrect use of pragma '${\__PACKAGE__}' at $f line $l.\n");
}

1;
__END__

=head1 NAME

strict - Perl pragma to restrict unsafe constructs

=head1 SYNOPSIS

    use strict;

    use strict "vars";
    use strict "refs";
    use strict "subs";

    use strict;
    no strict "vars";

=head1 DESCRIPTION

The C<strict> pragma disables certain Perl expressions that could behave
unexpectedly or are difficult to debug, turning them into errors. The
effect of this pragma is limited to the current file or scope block.

If no import list is supplied, all possible restrictions are assumed.
(This is the safest mode to operate in, but is sometimes too strict for
casual programming.)  Currently, there are three possible things to be
strict about:  "subs", "vars", and "refs".

=over 6

=item C<strict refs>

This generates a runtime error if you 
use symbolic references (see L<perlref>).

    use strict 'refs';
    $ref = \$foo;
    print $$ref;	# ok
    $ref = "foo";
    print $$ref;	# runtime error; normally ok
    $file = "STDOUT";
    print $file "Hi!";	# error; note: no comma after $file

There is one exception to this rule:

    $bar = \&{'foo'};
    &$bar;

is allowed so that C<goto &$AUTOLOAD> would not break under stricture.


=item C<strict vars>

This generates a compile-time error if you access a variable that was
neither explicitly declared (using any of C<my>, C<our>, C<state>, or C<use
vars>) nor fully qualified.  (Because this is to avoid variable suicide
problems and subtle dynamic scoping issues, a merely C<local> variable isn't
good enough.)  See L<perlfunc/my>, L<perlfunc/our>, L<perlfunc/state>,
L<perlfunc/local>, and L<vars>.

    use strict 'vars';
    $X::foo = 1;	 # ok, fully qualified
    my $foo = 10;	 # ok, my() var
    local $baz = 9;	 # blows up, $baz not declared before

    package Cinna;
    our $bar;			# Declares $bar in current package
    $bar = 'HgS';		# ok, global declared via pragma

The local() generated a compile-time error because you just touched a global
name without fully qualifying it.

Because of their special use by sort(), the variables $a and $b are
exempted from this check.

=item C<strict subs>

This disables the poetry optimization, generating a compile-time error if
you try to use a bareword identifier that's not a subroutine, unless it
is a simple identifier (no colons) and that it appears in curly braces or
on the left hand side of the C<< => >> symbol.

    use strict 'subs';
    $SIG{PIPE} = Plumber;   # blows up
    $SIG{PIPE} = "Plumber"; # fine: quoted string is always ok
    $SIG{PIPE} = \&Plumber; # preferred form

=back

See L<perlmodlib/Pragmatic Modules>.

=head1 HISTORY

C<strict 'subs'>, with Perl 5.6.1, erroneously permitted to use an unquoted
compound identifier (e.g. C<Foo::Bar>) as a hash key (before C<< => >> or
inside curlies), but without forcing it always to a literal string.

Starting with Perl 5.8.1 strict is strict about its restrictions:
if unknown restrictions are used, the strict pragma will abort with

    Unknown 'strict' tag(s) '...'

As of version 1.04 (Perl 5.10), strict verifies that it is used as
"strict" to avoid the dreaded Strict trap on case insensitive file
systems.

Starting with cperl (based on Perl 5.22) strict is now a builtin module,
implemented as XS functions which are always available.

=cut
