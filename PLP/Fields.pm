#----------------------#
  package PLP::Fields;
#----------------------#
use strict;

=head1 PLP::Fields

Has only one function: doit(), which ties the hashes %get, %post, %fields and %header in
PLP::Script. Also generates %cookie immediately.

    PLP::Fields::doit();

This module is part of the PLP internals. Don't use it yourself.

=cut

sub doit {
    tie %PLP::Script::get, 'PLP::Tie::Delay', 'PLP::Script::get', sub {
	my %get;
	my $get;
	$get = $ENV{QUERY_STRING};
	if ($get ne ''){
	    for (split /[&;]/, $get) {
		my @keyval = split /=/, $_, 2;
		PLP::Functions::DecodeURI(@keyval);
		$get{$keyval[0]} = $keyval[1] unless $keyval[0] =~ /^\@/;
		push @{ $get{'@' . $keyval[0]} }, $keyval[1];
	    }
	}
	return \%get;
    };

    tie %PLP::Script::post, 'PLP::Tie::Delay', 'PLP::Script::post', sub {
	my %post;
	my $post;
	if ($ENV{MOD_PERL}) {
	    $post = Apache->request->content;
	} else {
	    read(*STDIN, $post, $ENV{CONTENT_LENGTH});
	}
	if (defined($post) && $post ne '' &&
	    ($ENV{CONTENT_TYPE} eq '' || $ENV{CONTENT_TYPE} eq 'application/x-www-form-urlencoded')){
	    for (split /&/, $post) {
		my @keyval = split /=/, $_, 2;
		PLP::Functions::DecodeURI(@keyval);
		$post{$keyval[0]} = $keyval[1] unless $keyval[0] =~ /^\@/;
		push @{ $post{'@' . $keyval[0]} }, $keyval[1];
	    }
	}
	return \%post;
    };

    tie %PLP::Script::fields, 'PLP::Tie::Delay', 'PLP::Script::fields', sub {
	$PLP::Script::get{PLPdummy}, $PLP::Script::post{PLPdummy}; # Trigger creation
	return {%PLP::Script::get, %PLP::Script::post}
    };

    tie %PLP::Script::header, 'PLP::Tie::Headers';

    if (defined($ENV{HTTP_COOKIE}) && $ENV{HTTP_COOKIE} ne ''){
	for (split /; ?/, $ENV{HTTP_COOKIE}) {
	    my @keyval = split /=/, $_, 2;
	    $PLP::Script::cookie{$keyval[0]} ||= $keyval[1];
	}
    }

}
1;
