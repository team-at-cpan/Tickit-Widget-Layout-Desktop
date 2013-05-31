package Tickit::Demo::Plugin::Placegrid;
use strict;
use warnings;
use parent qw(Tickit::Demo::Widget);

use Tickit::Widget::Placegrid;

sub label { 'Placegrid' }

sub widget {
	my $class = shift;
	Tickit::Widget::Placegrid->new
}

1;
