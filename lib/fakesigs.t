#!./perl

BEGIN {
	chdir 't' if -d 't';
	@INC = '../lib';
	require './test.pl';
}

#use strict;
#use Config;
plan 3;
use_ok( 'fakesigs' );

sub fake { my ($a) = @_; ok(1) }

{
  no fakesigs;
  sub no_fake { my ($a) = @_; ok(1) }
}

fake();
no_fake();
