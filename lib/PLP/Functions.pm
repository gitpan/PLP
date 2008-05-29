package PLP::Functions;

use base 'Exporter';
use Fcntl qw(:flock);
use strict;

our @EXPORT = qw/Entity DecodeURI EncodeURI Include include PLP_END
                 AddCookie ReadFile WriteFile AutoURL Counter exit/;

sub Include ($) {
	no strict;
	$PLP::file = $_[0];
	$PLP::inA = 0;
	$PLP::inB = 0;
	local $@;
	eval 'package PLP::Script; ' . PLP::source($PLP::file, 0, join ' ', (caller)[2,1]);
	if ($@) {
		PLP::Functions::exit() if $@ =~ /\cS\cT\cO\cP/;
		PLP::error($@, 1);
	}
}

sub include ($) {
	goto &Include;
}

sub exit (;$) {
	die "\cS\cT\cO\cP\n";
}

sub PLP_END (&) {
	push @PLP::END, shift;
}

sub Entity (@) {
	my $ref = defined wantarray ? [@_] : \@_;
	for (@$ref) {
		eval {
			s/&/&amp;/g;
			s/"/&quot;/g;
			s/</&lt;/g;
			s/>/&gt;/g;
			s/\n/<br>\n/g;
			s/\t/&nbsp; &nbsp; &nbsp; &nbsp;&nbsp;/g;
			s/  /&nbsp;&nbsp;/g;
		};
	}
	return defined wantarray ? (wantarray ? @$ref : "@$ref") : undef;
}

sub DecodeURI (@) {
	my $ref = defined wantarray ? [@_] : \@_;
	for (@$ref) {
		eval {
			tr/+/ /;  # Browsers do tr/ /+/ - I don't care about RFCs, but
			          # I do care about real-life situations.
			s/%([0-9A-Fa-f][0-9A-Fa-f])/chr hex $1/ge;
		};
	}
	return defined wantarray ? (wantarray ? @$ref : "@$ref") : undef;
}

sub EncodeURI (@) {
	my $ref = defined wantarray ? [@_] : \@_;
	for (@$ref) {
		eval {
			s{([^A-Za-z0-9\-_.!~*'()/?:@\$,])}{sprintf("%%%02x", ord $1)}ge;
		};
	}
	return defined wantarray ? (wantarray ? @$ref : "@$ref") : undef;
}

sub AddCookie ($) {
	if ($PLP::Script::header{'Set-Cookie'}) {
		$PLP::Script::header{'Set-Cookie'} .= "\nSet-Cookie: $_[0]";
	} else {
		$PLP::Script::header{'Set-Cookie'} = $_[0];
	}
}

sub ReadFile ($) {
	local $/ = undef;
	open (my $fh, '<', $_[0]) or do {
		PLP::error("Cannot open $_[0] for reading ($!)", 1);
		return undef;
	};
	my $r = readline $fh;
	close $fh;
	return $r;
}

sub WriteFile ($$) {
	open (my $fh, '>', $_[0]) or do {
		PLP::error("Cannot open $_[0] for writing ($!)", 1);
		return undef;
	};
	flock $fh, LOCK_EX;
	print $fh $_[1] or do {
		PLP::error("Cannot write to $_[0] ($!)");
		return undef;
	};
	close $fh or do {
		PLP::error("Cannot close $_[0] ($!)");
		return undef;
	};
	return 1;
}

sub Counter ($) {
	local $/ = undef;
	my             $fh;
	open           $fh, '+<', $_[0] or
	open           $fh, '>',  $_[0] or return undef;
	flock          $fh, 2;
	seek           $fh, 0, 0;
	my $counter = <$fh>;
	seek           $fh, 0, 0;
	truncate       $fh, 0;
	print          $fh ++$counter   or return undef;
	close          $fh              or return undef;
	return $counter;
}

sub AutoURL ($) {
	# This sub assumes your string does not match /(["<>])\cC\1/
	my $ref = defined wantarray ? \(my $copy = $_[0]) : \$_[0];
	eval {
		$$ref =~ s/&quot;/"\cC"/g; # Single characters are easier to match :)
		$$ref =~ s/&gt;/>\cC>/g;   # so we can just use a character class []
		$$ref =~ s/&lt;/<\cC</g;
		
		# Now this is a big, ugly regex! But hey - it works :)
		$$ref =~ s{((\w+://|www\.|WWW\.)[a-zA-Z0-9\.\@:-]+[^\"\'>< \r\t\n]*)}{
			local $_ = $1;
			my $scheme = $2;
			s/// if (my $trailing) = /([\.,!\?\(\)\[\]]+$)/;
			s/&(?!\x23?\w+;)/&amp;/g;
			s/\"/&quot;/g;
			my $href = ($scheme =~ /www\./i ? "http://$_" : $_);
			qq{<a href="$href" target="_blank">$_</a>$trailing};
		}eg;

		$$ref =~ s/"\cC"/&quot;/g;
		$$ref =~ s/>\cC>/&gt;/g;
		$$ref =~ s/<\cC</&lt;/g;
	};
	if ($@){ return defined wantarray ? @_ : undef }  # return original on error
	return defined wantarray ? $$ref : undef;
}

1;

=head1 NAME

PLP::Functions - Functions that are available in PLP documents

=head1 DESCRIPTION

The functions are exported into the PLP::Script package that is used by PLP documents. Although uppercased letters are unusual in Perl, they were chosen to stand out.

Most of these functions are context-hybird. Before using them, one should know about contexts in Perl. The three major contexts are: B<void>, B<scalar> and B<list> context. You'll find more about context in L<perlfunc>.

Some context examples:

    print foo();  # foo is in list context (print LIST)
    foo();        # foo is in void context
    $bar = foo(); # foo is in scalar context
    @bar = foo(); # foo is in list context
    length foo(); # foo is in scalar context (length EXPR)

=head2 The functions

=over 10

=item Include FILENAME

Executes another PLP file, that will be parsed (i.e. code must be in C<< <: :> >>). As with Perl's C<do>, the file is evaluated in its own lexical file scope, so lexical variables (C<my> variables) are not shared. PLP's C<< <(filename)> >> includes at compile-time, is faster and is doesn't create a lexical scope (it shares lexical variables).

Include can be used recursively, and there is no depth limit:

    <!-- This is crash.plp -->
    <:
        include 'crash.plp';
        # This example will loop forever,
        # and dies with an out of memory error.
	# Do not try this at home.
    :>

=item include FILENAME

An alias for C<Include>.

=item PLP_END BLOCK

Adds a piece of code that is executed when at the end of the PLP document. This is useful when creating a template file:

    <html><body>       <!-- this is template.plp -->
    <: PLP_END { :>
    </body></html>
    <: } :>

    <(template.plp)>   <!-- this is index.plp -->
    Hello, world!

You should use this function instead of Perl's built-in C<END> blocks, because those do not work properly with mod_perl.

=item Entity LIST

Replaces HTML syntax characters by HTML entities, so they can be displayed literally. You should always use this when displaying user input (or database output), to avoid cross-site-scripting vurnerabilities.

In void context, B<changes> the values of the given variables. In other contexts, returns the changed versions.

    <: print Entity($user_input); :>

Be warned that this function also HTMLizes consecutive whitespace and newlines (using &nbsp; and <br> respectively).
For simple escaping, use L<XML::Quote|XML::Quote>.
To escape high-bit characters as well, use L<HTML::Entities|HTML::Entities>.

=item EncodeURI LIST

Encodes URI strings according to RFC 3986. All disallowed characters are replaced by their %-encoded values.

In void context, B<changes> the values of the given variables. In other contexts, returns the changed versions.

    <a href="/foo.plp?name=<:= EncodeURI($name) :>">Link</a>

Note that the following reserved characters are I<not> percent-encoded, even though they may have a special meaning in URIs:

	/ ? : @ $

This should be safe for escaping query values (as in the example above),
but it may be a better idea to use L<URI::Escape|URI::Escape> instead.

=item DecodeURI LIST

Decodes %-encoded strings. Unlike L<URI::Escape|URI::Escape>,
it also translates + characters to spaces (as browsers use those).

In void context, B<changes> the values of the given variables. In other contexts, returns the changed versions.

=item ReadFile FILENAME

Returns the contents of FILENAME in one large string. Returns undef on failure.

=item WriteFile FILENAME, STRING

Writes STRING to FILENAME (overwrites FILENAME if it already exists). Returns true on success, false on failure.

=item Counter FILENAME

Increases the contents of FILENAME by one and returns the new value. Returns undef on failure. Fails silently.

    You are visitor number <:= Counter('counter.txt') :>.

=item AutoURL STRING

Replaces URLs (actually, replace things that look like URLs) by links.

In void context, B<changes> the value of the given variable. In other contexts, returns the changed version.

    <: print AutoURL(Entity($user_input)); :>

=item AddCookie STRING

Adds a Set-Cookie header. STRING must be a valid Set-Cookie header value.

=back

=head1 AUTHOR

Juerd Waalboer <juerd@cpan.org>

Current maintainer: Mischa POSLAWSKY <shiar@cpan.org>

=cut

