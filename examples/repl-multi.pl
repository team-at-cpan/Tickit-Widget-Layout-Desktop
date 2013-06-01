#!/usr/bin/env perl 
use strict;
use warnings;
use Tickit::DSL;
use Eval::WithLexicals;
use Try::Tiny;
use Data::Dumper;
use JavaScript::V8;

my $eval = Eval::WithLexicals->with_plugins("HintPersistence")->new(
	context => 'scalar',
);
my $ctx = JavaScript::V8::Context->new;
my %handler = (
	perl => sub { my ($rslt) = $eval->eval(shift); $rslt },
	js => sub { my $rslt = $ctx->eval(shift); die $@ if $@; $rslt },
);
vbox {
	my $scroller;
	widget {
		$scroller = scroller { };
	} expand => 1;
	entry {
		my ($self, $data) = @_;
		widget { scroller_text $data } parent => $scroller;
		my ($lang, $code) = $data =~ /^(perl|js|sql):\s*(.*)$/ims;
		try {
			my $rslt = $handler{lc $lang}->($code);
			my $output = do {
				no warnings 'once';
				local $Data::Dumper::Terse = 1;
				local $Data::Dumper::Indent = 1;
				local $Data::Dumper::Useqq = 1;
				local $Data::Dumper::Deparse = 1;
				local $Data::Dumper::Sortkeys = 1;
				local $Data::Dumper::QuoteKeys = 0;
				Dumper($rslt)
			};
			widget { scroller_text $output } parent => $scroller
		} catch {
			my $err = $_;
			widget { scroller_text "Error: $err" } parent => $scroller
		};
		$scroller->scroll_to_bottom
	};
};
tickit->run;

