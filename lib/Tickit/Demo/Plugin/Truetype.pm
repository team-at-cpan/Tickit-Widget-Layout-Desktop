package Tickit::Demo::Plugin::Truetype;
use strict;
use warnings;
use parent qw(Tickit::Demo::Widget);

use Tickit::Widget::VBox;
use Tickit::Widget::Entry;
use Tickit::Widget::Truetype;

sub label { 'Truetype font rendering' }

sub widget {
	my $class = shift;
	my $vbox = Tickit::Widget::VBox->new;
	my $txt = 'Tickit';
	my $ttf = Tickit::Widget::Truetype->new(
		font => 'demo.ttf',
		text => $txt,
	);
	$vbox->add(my $entry = Tickit::Widget::Entry->new(
		text => $txt,
		on_enter => sub {
			my ($self, $line) = @_;
			$ttf->set_text($line);
		}
	));
	$vbox->add($ttf, expand => 1);
	$vbox
}

1;
