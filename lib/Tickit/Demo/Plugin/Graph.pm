package Tickit::Demo::Plugin::Graph;
use strict;
use warnings;
use parent qw(Tickit::Demo::Widget);

use Tickit::Widget::HBox;
use Tickit::Widget::VBox;
use Tickit::Widget::Progressbar::Vertical;
use Tickit::Widget::Progressbar::Horizontal;

sub label { 'Graph' }

sub widget {
	my $class = shift;
	my $hbox = Tickit::Widget::HBox->new;
	$hbox->add(my $graphs = Tickit::Widget::VBox->new, expand => 1);
	$graphs->add(my $send = Tickit::Widget::HBox->new, expand => 2);
	$send->add(Tickit::Widget::Progressbar::Vertical->new(fg => 'green', completion => $_), expand => 1) for 0,0.1,0.18,0.19,0.23,0.47,0.76,0.99,0.56,0.31,0.15,0.08,0.00;
	$graphs->add(Tickit::Widget::Static->new(text => 'Send: 38ms', align => 'centre'));
	$graphs->add(my $listen = Tickit::Widget::HBox->new, expand => 2);
	$listen->add(Tickit::Widget::Progressbar::Vertical->new(fg => 'red', completion => $_), expand => 1) for 0.04,0.12,0.34,0.46,0.21,0.40,0.56,0.89,0.26,0.08,0.15,0.08,0.63;
	$graphs->add(Tickit::Widget::Static->new(text => 'Listen: 72ms', align => 'centre'));
	$hbox;
}

1;

