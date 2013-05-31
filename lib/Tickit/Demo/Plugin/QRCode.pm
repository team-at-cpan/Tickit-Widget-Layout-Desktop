package Tickit::Demo::Plugin::QRCode;
use strict;
use warnings;
use parent qw(Tickit::Demo::Widget);

use Tickit::Widget::VBox;
use Tickit::Widget::Entry;
use Tickit::Widget::QRCode;

sub label { 'QR Code' }

sub widget {
	my $class = shift;
	my $vbox = Tickit::Widget::VBox->new;
	my $txt = 'http://github.com/ingydotnet/tickit-info';
	my $qr = Tickit::Widget::QRCode->new(
		text => $txt,
	);
	$vbox->add(my $entry = Tickit::Widget::Entry->new(
		text => $txt,
		on_enter => sub {
			my ($self, $line) = @_;
			$qr->set_text($line);
		}
	));
	$vbox->add($qr, expand => 1);
	$vbox
}

1;
