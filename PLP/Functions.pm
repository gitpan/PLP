#-------------------------#
  package PLP::Functions;
#-------------------------#
use base 'Exporter';
use strict;

our @EXPORT = qw/HiddenFields Entity DecodeURI EncodeURI Entity include PLP_END
                 AddCookie ReadFile WriteFile AutoURL Counter Include exit/;

sub Include ($) {
    no strict;
    $PLP::file = $_[0];
    $PLP::inA = 0;
    $PLP::inB = 0;
    local $@;
    eval 'package PLP::Script; ' . PLP::source($PLP::file, 0, join ' ', (caller)[2,1]);
    if ($@) {
	PLP::Functions::exit if $@ =~ /\cS\cT\cO\cP/;
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

sub HiddenFields ($@) {
    my $hash = shift;
    my %saves;
    @saves{@_} = ();
    for (keys %$hash) {
	print qq{<input type=hidden name="$_" value="$hash->{$_}">}
	    unless exists $saves{$_};
    }
}

sub Entity (@) {
    my $ref;
    my @copy;    
    if (defined wantarray) {
	@copy = @_;
	$ref = \@copy;
    } else {
	$ref = \@_;
    }
    for (@$ref) {
	eval {
	    s/&/&amp;/g;
	    s/\"/&quot;/g;
	    s/</&lt;/g;
	    s/>/&gt;/g;
	    s/\n/<br>\n/g;
	    s/\t/&nbsp; &nbsp; &nbsp; &nbsp;&nbsp;/g;
	    s/  /&nbsp;&nbsp;/g;
	};
#	if ($@){ return defined wantarray ? @_ : undef }
    }
    return defined wantarray ? (wantarray ? @$ref : "@$ref") : undef;
}

# Browsers do s/ /+/ - I don't care about RFC's, but I do care about real-life
# situations.
sub DecodeURI (@) {
    my @r;
    local $_;    
    for (@_) {
	s/\+/%20/g;
	my $dec = $_;
	$dec =~ s/%([0-9A-Fa-f][0-9A-Fa-f])/chr hex $1/ge;
	if (defined wantarray) {
	    push @r, $dec;
	} else {
	    eval {$_ = $dec}; 
#	    return undef if $@; # ;DecodeURI("foo");
	}
    }
    return defined wantarray ? (wantarray ? @r : "@r") : undef;
}
sub EncodeURI (@) {
    my @r;
    local $_;
    for (@_) {
        my $esc = $_;
	$esc =~ 
	    s{
		([^\/?:@\$,A-Za-z0-9\-_.!~*\'()])
	    }{
		sprintf("%%%02x", ord($1))
	    }xge;
        if (defined wantarray) {
            push @r, $esc;
        } else {
	    eval {$_ = $esc};
#	    return undef if $@; # ;EncodeURI("foo");
	}
    }
    return defined wantarray ? (wantarray ? @r : "@r") : undef;
}

sub AddCookie ($) {
    if ($PLP::Script::header{'Set-Cookie'}) {
	$PLP::Script::header{'Set-Cookie'} .= "\nSet-Cookie: $_[0]";
    } else {
	$PLP::Script::header{'Set-Cookie'} = $_[0];
    }
}

sub ReadFile ($) {
    local *READFILE;
    local $/ = undef;
    open (READFILE, '<', $_[0]);
    my $r = <READFILE>;
    close READFILE;
    return $r;
}

sub WriteFile ($$) {
    local *WRITEFILE;
    open (WRITEFILE, '>', $_[0]);
    flock WRITEFILE, 2;
    print WRITEFILE $_[1];
    close WRITEFILE;
}

sub Counter ($) {
    local *COUNTER;
    local $/ = undef;
    open           COUNTER, '+<', $_[0] or
    open	   COUNTER, '>',  $_[0] or return undef;
    flock          COUNTER, 2;
    seek           COUNTER, 0, 0;
    my $counter = <COUNTER>;
    seek           COUNTER, 0, 0;
    truncate       COUNTER, 0;
    print          COUNTER ++$counter;
    close          COUNTER;
    return $counter;
}

sub AutoURL ($) {
    # This sub assumes your string does not match /(["<>])\cC\1/
    my $ref;    
    if (defined wantarray){
	$ref = \(my $copy = $_[0]);
    }else{
	$ref = \$_[0];
    }
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
    if ($@){ return defined wantarray ? @_ : undef }
    return defined wantarray ? $$ref : undef;
}


1;
