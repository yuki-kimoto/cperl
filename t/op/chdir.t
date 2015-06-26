#!./perl -w

BEGIN {
    # We really want to know if chdir is working, as the build process will
    # all go wrong if it is not.  So avoid clearing @INC under miniperl.
    @INC = () if defined &DynaLoader::boot_DynaLoader;

    # We're not going to chdir() into 't' because we don't know if
    # chdir() works!  Instead, we'll hedge our bets and put both
    # possibilities into @INC.
    unshift @INC, qw(t . lib ../lib);
    require "./test.pl";
    plan(tests => 42);
}

use Config;
use Errno qw(ENOENT);

my $IsVMS   = $^O eq 'VMS';

# For an op regression test, I don't want to rely on "use constant" working.
my $has_fchdir = ($Config{d_fchdir} || "") eq "define";

# Might be a little early in the testing process to start using these,
# but I can't think of a way to write this test without them.
use File::Spec::Functions qw(:DEFAULT splitdir rel2abs splitpath);

# Can't use Cwd::abs_path() because it has different ideas about
# path separators than File::Spec.
sub abs_path {
    my $d = rel2abs(curdir);
    $d = lc($d) if $^O =~ /^uwin/;
    $d;
}

my $Cwd = abs_path;

# Let's get to a known position
SKIP: {
    my ($vol,$dir) = splitpath(abs_path,1);
    my $test_dir = 't';
    my $compare_dir = (splitdir($dir))[-1];

    # VMS is case insensitive but will preserve case in EFS mode.
    # So we must normalize the case for the compare.
 
    $compare_dir = lc($compare_dir) if $IsVMS;
    skip("Already in t/", 2) if $compare_dir eq $test_dir;

    ok( chdir($test_dir),     'chdir($test_dir)');
    is( abs_path, catdir($Cwd, $test_dir),    '  abs_path() agrees' );
}

$Cwd = abs_path;

SKIP: {
    skip("no fchdir", 16) unless $has_fchdir;
    my $has_dirfd = ($Config{d_dirfd} || $Config{d_dir_dd_fd} || "") eq "define";
    ok(opendir(my $dh, "."), "opendir .");
    ok(open(my $fh, "<", "op"), "open op");
    ok(chdir($fh), "fchdir op");
    ok(-f "chdir.t", "verify that we are in op");
    if ($has_dirfd) {
       ok(chdir($dh), "fchdir back");
    }
    else {
       eval { chdir($dh); };
       like($@, qr/^The dirfd function is unimplemented at/, "dirfd is unimplemented");
       chdir ".." or die $!;
    }

    # same with bareword file handles
    no warnings 'once';
    *DH = $dh;
    *FH = $fh;
    ok(chdir FH, "fchdir op bareword");
    ok(-f "chdir.t", "verify that we are in op");
    if ($has_dirfd) {
       ok(chdir DH, "fchdir back bareword");
    }
    else {
       eval { chdir(DH); };
       like($@, qr/^The dirfd function is unimplemented at/, "dirfd is unimplemented");
       chdir ".." or die $!;
    }
    ok(-d "op", "verify that we are back");

    # And now the ambiguous case
    {
	no warnings qw<io deprecated>;
	ok(opendir(H, "op"), "opendir op") or diag $!;
	ok(open(H, "<", "base"), "open base") or diag $!;
    }
    if ($has_dirfd) {
	ok(chdir(H), "fchdir to op");
	ok(-f "chdir.t", "verify that we are in 'op'");
	chdir ".." or die $!;
    }
    else {
	eval { chdir(H); };
	like($@, qr/^The dirfd function is unimplemented at/,
	     "dirfd is unimplemented");
	SKIP: {
	    skip("dirfd is unimplemented");
	}
    }
    ok(closedir(H), "closedir");
    ok(chdir(H), "fchdir to base");
    ok(-f "cond.t", "verify that we are in 'base'");
    chdir ".." or die $!;
}

SKIP: {
    skip("has fchdir", 1) if $has_fchdir;
    opendir(my $dh, "op");
    eval { chdir($dh); };
    like($@, qr/^The fchdir function is unimplemented at/, "fchdir is unimplemented");
}

# The environment variables chdir() pays attention to.
my @magic_envs = qw(HOME LOGDIR SYS$LOGIN);

sub check_env {
    my($key) = @_;

    # Make sure $ENV{'SYS$LOGIN'} is only honored on VMS.
    if( $key eq 'SYS$LOGIN' && !$IsVMS ) {
        ok( !chdir(),         "chdir() on $^O ignores only \$ENV{$key} set" );
        is( abs_path, $Cwd,   '  abs_path() did not change' );
        pass( "  no need to test SYS\$LOGIN on $^O" ) for 1..7;
    }
    else {
        ok( chdir(),              "chdir() w/ only \$ENV{$key} set" );
        is( abs_path, $ENV{$key}, '  abs_path() agrees' );
        chdir($Cwd);
        is( abs_path, $Cwd,       '  and back again' );

        my $warning = '';
        local $SIG{__WARN__} = sub { $warning .= join '', @_ };
        $! = 0;
        ok(!chdir(''), "chdir('') no longer implied chdir()");
        is($!+0, ENOENT, 'check $! set appropriately');
        is($warning, '', 'should no longer warn about deprecation');
    }
}

my %Saved_Env = ();
sub clean_env {
    foreach my $env (@magic_envs) {
        $Saved_Env{$env} = $ENV{$env};

        # Can't actually delete SYS$ stuff on VMS.
        next if $IsVMS && $env eq 'SYS$LOGIN';
        next if $IsVMS && $env eq 'HOME' && !$Config{'d_setenv'};

	# On VMS, %ENV is many layered.
	delete $ENV{$env} while exists $ENV{$env};
    }

    # The following means we won't really be testing for non-existence,
    # but in Perl we can only delete from the process table, not the job 
    # table.
    $ENV{'SYS$LOGIN'} = '' if $IsVMS;
}

END {
    no warnings 'uninitialized';

    # Restore the environment for VMS (and doesn't hurt for anyone else)
    @ENV{@magic_envs} = @Saved_Env{@magic_envs};

    # On VMS this must be deleted or process table is wrong on exit
    # when this script is run interactively.
    delete $ENV{'SYS$LOGIN'} if $IsVMS;
}


foreach my $key (@magic_envs) {
    # We're going to be using undefs a lot here.
    no warnings 'uninitialized';

    clean_env;
    $ENV{$key} = catdir $Cwd, ($IsVMS ? 'OP' : 'op');

    check_env($key);
}

{
    clean_env;
    if ($IsVMS && !$Config{'d_setenv'}) {
        pass("Can't reset HOME, so chdir() test meaningless");
    } else {
        ok( !chdir(),                   'chdir() w/o any ENV set' );
    }
    is( abs_path, $Cwd,             '  abs_path() agrees' );
}
