package fakesigs;
our $VERSION = '0.01';
sub unimport { $^H{no_fakesigs} = 1; }
sub import { delete $^H{no_fakesigs}; }

1;
__END__

=head1 NAME

fakesigs - disallow fake signature optimizations

=head1 SYNOPSIS

    no fakesigs;
    sub inc_arg { my ($self, $arg) = @_; $arg++ }

=head1 DESCRIPTION

This is a new lexical user-pragma since cperl5.22.2 to disable the
compiler optimization converting normal functions to fake signatures,
when the first line in the body is like C<my ($vars...) = @_;>.

This might be needed if the function is also processed by source
filters, e.g.  L<Test::Base> with L<Spiffy>.

=cut
