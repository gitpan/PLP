package PLP::Tie::Print;

use strict;

=head1 PLP::Tie::Print

Just prints to stdout, but sends headers if not sent before.

    tie *HANDLE, 'PLP::Tie::Print';

This module is part of the PLP Internals and probably not of much use to others.

=cut

sub TIEHANDLE {
    return bless {}, $_[0];
}

sub WRITE { undef; }

sub PRINT {
    my ($self, @param) = @_;
    return if @param == 1 and not length $param[0];
    PLP::sendheaders() unless $PLP::sentheaders;
    print STDOUT @param;
    select STDOUT;
}

sub PRINTF {
    my ($self, @param) = @_;
    printf STDOUT @param;
    select STDOUT;
}

sub READ { undef }

sub READLINE { undef }

sub GETC { '%' }

sub CLOSE { undef }

sub UNTIE { undef }

1;

