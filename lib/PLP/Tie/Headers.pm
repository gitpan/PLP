package PLP::Tie::Headers;

use strict;
use Carp;

=head1 PLP::Tie::Headers

Makes a hash case insensitive, and sets some headers. <_> equals <->, so C<$foo{CONTENT_TYPE}> is
the same as C<$foo{'Content-Type'}>.

	tie %somehash, 'PLP::Tie::Headers';

This module is part of the PLP internals and probably not of much use to others.

=cut

sub TIEHASH {
	return bless [ # Defaults
		{
			'Content-Type'  => 'text/html',
			'X-PLP-Version' => $PLP::VERSION,
		},
		{
			'content-type'  => 'Content-Type',
			'x-plp-version' => 'X-PLP-Version',
		}
	], $_[0];
}

sub FETCH {
	my ($self, $key) = @_;
	$key =~ tr/_/-/;
	return $self->[0]->{ $self->[1]->{lc $key} };
}

sub STORE {
	my ($self, $key, $value) = @_;
	$key =~ tr/_/-/;
	if ($PLP::sentheaders) {
		my @caller = caller;
		die "Can't set headers after sending them at " .
		    "$caller[1] line $caller[2].\n(Output started at " .
		    "$PLP::sentheaders->[0] line $PLP::sentheaders->[1].)\n"
	}
	if (defined $self->[1]->{lc $key}){
		$key = $self->[1]->{lc $key};
	} else {
		$self->[1]->{lc $key} = $key;
	}
	return ($self->[0]->{$key} = $value);
}

sub DELETE {
	my ($self, $key) = @_;
	$key =~ tr/_/-/;
	delete $self->[0]->{$key};
	return delete $self->[1]->{lc $key};
}

sub CLEAR {
	my $self = $_[0];
	return (@$self = ());
}

sub EXISTS {
	my ($self, $key) = @_;
	$key =~ tr/_/-/;
	return exists $self->[1]->{lc $key};
}

sub FIRSTKEY {
	my $self = $_[0];
	keys %{$self->[0]};
	return each %{ $self->[0] }; # Key only, Tie::Hash doc is wrong.
}

sub NEXTKEY {
	return each %{ $_[0]->[0] };
}

1;

