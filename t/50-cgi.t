use strict;
use warnings;

use Cwd;
use File::Spec;
use Test::More;

eval { require PerlIO::scalar };
plan skip_all => "PerlIO required (perl 5.8) to test PLP" if $@;

plan tests => 18;

require_ok('PLP::Backend::CGI') or BAIL_OUT();

$PLP::use_cache = 0 if $PLP::use_cache;
#TODO: caching on (change file names)

my $base = Cwd::abs_path(File::Spec->tmpdir || File::Spec->curdir);
-w $base or BAIL_OUT("$base not writable");
my $testfile = 'testfile.plp';
not -f "$base/$testfile" or BAIL_OUT("$testfile exists");

open ORGOUT, '>&', *STDOUT;

sub plp_is {
	my ($test, $plp, $expect) = @_;
	chomp $expect;
	local $Test::Builder::Level = $Test::Builder::Level + 1;

	eval {
		open my $testfh, '>', "$base/$testfile" or die $!;
		print {$testfh} $plp or die $!;
		close $testfh or die $!;
	};
	not $@ or fail("write $testfile"), diag("    Error: $@"), return;

	close STDOUT;
	open STDOUT, '>', \my $output;  # STDOUT buffered to scalar
	eval {
		local $SIG{__WARN__} = sub { print $_[0] }; # enables warnings
		PLP::everything();
	};
	select ORGOUT;  # return to original STDOUT

	not $@ or fail($test), diag("    Error: $@"), return;
	$output =~ s{((?:.+\n)*)}{ join "", sort split /(?<=\n)/, $1 }e; # order headers
	is($output, $expect, $test);
}

%ENV = (
	REQUEST_METHOD => 'GET',
	REQUEST_URI => "/$testfile/test/123",
	QUERY_STRING => 'test=1&test=2',
	GATEWAY_INTERFACE => 'CGI/1.1',
	
	SCRIPT_NAME => '/plp.cgi',
	SCRIPT_FILENAME => "$base/plp.cgi",
	PATH_INFO => "/$testfile/test/123",
	PATH_TRANSLATED => "$base/$testfile/test/123",
	DOCUMENT_ROOT => $base,
); # Apache/2.2.4 CGI environment

my $HEAD = <<EOT;  # common header output
Content-Type: text/html
X-PLP-Version: $PLP::VERSION
EOT

plp_is('print', '0<: print print 2 :>3', "$HEAD\n0213");

plp_is('exit', '1<:exit:>not <(reached)>', "$HEAD\n1");

plp_is('<:=', '1<:=$foo=2:>3<:= $foo', "$HEAD\n1232");

plp_is('%get', '<: print $get{test} if defined $get{test} and not exists $get{test2}', "$HEAD\n2\n");

plp_is('%get array', '<:= @{$get{q/@test/}}', "$HEAD\n12\n");

plp_is('%header',
	'<: $headers{_test}=2; print $header{x_PLP_version}; BEGIN { $header{"-tesT"}=1 }',
	"-tesT: 2\n$HEAD\n$PLP::VERSION"
);

plp_is('%header repetition', '.<: BEGIN{$header{A}="1\n2"} $header{A}=3', <<TEST);
A: 1
A: 2
$HEAD
.<table border=1 class="PLPerror"><tr><td><b>Debug information:</b><br>Can't set headers after sending them at testfile.plp line 1.
(Output started at testfile.plp line 1.)
</td></tr></table>
TEST

#TODO: %post
#TODO: %fields
#TODO: %cookie

plp_is('PLP_END', '<: PLP_END{print 1}; PLP_END{print 2}; print 3', "$HEAD\n321");

plp_is('no warnings by default', '<: ignoreme :>ok', "$HEAD\nok");

rename "$base/$testfile", "$base/$testfile.inc";
plp_is('include', "<($testfile.inc)> <: include '$testfile.inc'", "$HEAD\nok ok");
unlink "$base/$testfile.inc";

plp_is('fatal error', "runtime\n<: syntax(error :>\nruntime", <<TEST);
$HEAD
<table border=1 class="PLPerror"><tr><td><b>Debug information:</b><br>syntax error at $testfile line 2, at EOF
  (Might be a runaway multi-line \cq\cq string starting on line 1)
</td></tr></table>
TEST

SKIP: {

my $INCFILE = File::Spec->rel2abs("$base/missinginclude");
if (open my $dummy, "<", $INCFILE) {  # like PLP::source will
	fail("file missinginclude shouldn't exist");
	skip("missinginclude tests", 2);
}
my $INCWARN = qq{Can't open "$INCFILE" ($!)};

plp_is('warnings', split /\n\n/, <<TEST, 2);
1
<: use warnings :>
2
<: 42 :>
3
<: warn "warning" :>
4
<: include "missinginclude" :>
5
<(missinginclude)>
6

$HEAD
Useless use of a constant in void context at $testfile line 4.
1

2

3
warning at $testfile line 6.

4
<table border=1 class="PLPerror"><tr><td><b>Debug information:</b><br>$INCWARN at $testfile line 8.
</td></tr></table>
5
<table border=1 class="PLPerror"><tr><td><b>Debug information:</b><br>$INCWARN at $testfile line 10.
</td></tr></table>
TEST

plp_is('$PLP::ERROR',
	'<: $PLP::ERROR = sub {print "Oh no: $_[0]"} :> <(missinginclude)>.',
	qq{$HEAD\n Oh no: $INCWARN at $testfile line 1.\n\n}
);

#TODO: 404
#TODO: 403

plp_is('$PLP::DEBUG',
	'<: $PLP::DEBUG = 2; delete $header{x_plp_version} :>1<(missinginclude)>2',
	"Content-Type: text/plain\n\nContent-Type: text/html\n\n1"
);

}

plp_is('utf8', '<: use open qw/:std :utf8/; print chr 191', <<TEST);
Content-Type: text/html; charset=utf-8
X-PLP-Version: $PLP::VERSION

\302\277
TEST

my @envtest = (
	'ok <:=$ENV{SCRIPT_NAME}:> <:=$ENV{SCRIPT_FILENAME}',
	"$HEAD\nok /$testfile $base/$testfile"
);

plp_is('%ENV (on apache)', @envtest);

%ENV = (
	REQUEST_METHOD => 'GET',
	REQUEST_URI => "/$testfile/test/123",
	QUERY_STRING => 'test=1&test=2',
	GATEWAY_INTERFACE => 'CGI/1.1',
	
	SCRIPT_NAME => "/$testfile", #XXX: .plp?
	SCRIPT_FILENAME => "$base/$testfile",
	PATH_INFO => '/test/123',
); # lighttpd/1.4.7 CGI environment

plp_is('%ENV on lighttpd', @envtest);

unlink "$base/$testfile";

