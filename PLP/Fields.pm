#----------------------#
  package PLP::Fields;
#----------------------#
use strict;

# Has only one function: doit(), which ties the hashes %get, %post, %fields and %header in
# PLP::Script. Also generates %cookie immediately.
sub doit {
    tie %PLP::Script::get, 'PLP::Tie::Delay', 'PLP::Script::get', sub {
	my %get;
	my $get = $ENV{QUERY_STRING};
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
	if (defined $post
	    and $post ne ''
	    and $ENV{CONTENT_TYPE} =~ m!^(?:application/x-www-form-urlencoded|$)!
	){
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
#	$PLP::Script::get{PLPdummy}, $PLP::Script::post{PLPdummy}; # Trigger creation
#	No longer necessary, as PLP::Tie::Delay has been fixed since 3.00
#	And fixed even more in 3.13
	return { %PLP::Script::get, %PLP::Script::post };
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

=head1 NAME

PLP::Fields - Special hashes for PLP

=head1 DESCRIPTION

For your convenience, PLP uses hashes to put things in. Some of these are tied
hashes, so they contain a bit magic. For example, building the hash can be
delayed until you actually use the hash.

=over 10

=item C<%get> and C<%post>

These are built from the C<key=value&key=value> (or C<key=value;key=value>
strings in query string and post content. C<%post> is not built if the content
type is not C<application/x-www-form-urlencoded>. In post content, the
semi-colon is not a valid separator.

These hashes aren't built until they are used, to speed up your script if you
don't use them. Because POST content can only be read once, you can C<use CGI;>
and just never access C<%post> to avoid its building.

With a query string of C<key=firstvalue&key=secondvalue>, C<$get{key}> will
contain only C<secondvalue>. You can access both elements by using the array
reference C<$get{'@key'}>, which will contain C<[ 'firstvalue', 'secondvalue'
]>.

=item C<%fields>

This hash combines %get and %post, and triggers creation of both. POST gets
precedence over GET (note: not even the C<@>-keys contain both values).

=item C<%cookie>, C<%cookies>

This is built immediately, because cookies are usually short in length. Cookies
are not automatically url-decoded.

=item C<%header>, C<%headers>

In this hash, you can set headers. Underscores are converted to normal minus
signs, so you can leave out quotes. The hash is case insensitive: the case used
when sending the headers is the one you used first. The following are equal:

    $header{CONTENT_TYPE}
    $header{'Content-Type'}
    $header{Content_Type}
    $headers{CONTENT_type}

=back

=head1 AUTHOR

Juerd Waalboer <juerd@juerd.nl>

=cut

