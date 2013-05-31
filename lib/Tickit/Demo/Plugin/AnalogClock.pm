package Tickit::Demo::Plugin::AnalogClock;
use strict;
use warnings;
use parent qw(Tickit::Demo::Widget);

use Tickit::Widget::Clock;

sub label { 'Crappy clock' }

sub widget {
	my $self = shift;
	Tickit::Widget::Clock->new(
		loop => $self->loop,
	)
}

1;
