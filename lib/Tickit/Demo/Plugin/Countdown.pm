package Tickit::Demo::Plugin::Countdown;
use strict;
use warnings;
use parent qw(Tickit::Demo::Widget);

use Tickit::Widget::Countdown;

sub label { 'final countdown' }

sub widget {
	my $self = shift;
	Tickit::Widget::Countdown->new(
		loop => $self->loop,
		font => 'demo.ttf',
	)
}

1;
