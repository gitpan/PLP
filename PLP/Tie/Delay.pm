#--------------------------#
  package PLP::Tie::Delay;
#--------------------------#
use strict;
no strict 'refs';

=head1 PLP::Tie::Delay

Delays hash generation. Unties the hash on first access, and replaces it by the generated one.
Uses symbolic references, because circular ties make Perl go nuts :)

    tie %Some::hash, 'PLP::Tie::Delay', 'Some::hash', sub { \%generated_hash };

This module is part of the PLP internals and probably not of any use to others.

=cut

sub _replace {
    my ($self) = @_;
    untie %{ $self->[0] };
    %{ $self->[0] } = %{ $self->[1]->() };
}

sub TIEHASH {
    my ($class, $hash, $source) = @_;
    return bless [ $hash, $source ], $class;
}

sub FETCH {
    my ($self, $key) = @_;
    $self->_replace;
    return ${ $self->[0] }{$key};
}

sub STORE {
    my ($self, $key, $value) = @_;
    $self->_replace;
    return ${ $self->[0] }{$key} = $value;
}

sub DELETE {
    my ($self, $key) = @_;
    $self->_replace;
    return delete ${ $self->[0] }{$key};
}

sub CLEAR {
    my ($self) = @_;
    $self->_replace;
    return %{ $self->[0] };
}

sub EXISTS {
    my ($self, $key) = @_;
    $self->_replace;
    return exists ${ $self->[0] }{$key};
}

sub FIRSTKEY {
    my ($self) = @_;
    $self->_replace;
    return 'PLPdummy';
}

sub NEXTKEY {
    my ($self) = @_;
    # Let's hope this never happens. (It's shouldn't.)
    return undef;
}

sub UNTIE   { }
sub DESTORY { } 

1;

