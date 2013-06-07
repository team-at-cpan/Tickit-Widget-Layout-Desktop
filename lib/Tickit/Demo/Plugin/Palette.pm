package Tickit::Demo::Plugin::Palette;
use strict;
use warnings;
use parent qw(Tickit::Demo::Widget);

use Tickit::Widget::Palette;

sub label { '256 colours' }

sub widget {
	my $class = shift;
	Tickit::Widget::Palette->new(
	);
}

1;
