#!/usr/bin/env perl 
use strict;
use warnings;
use Tickit::Async;
use Tickit::Widget::Desktop;
use Tickit::Widget::Placegrid;
use Tickit::Widget::VBox;
use Tickit::Widget::Statusbar;
use Tickit::Widget::Clock;
use IO::Async::Loop;

my $loop = IO::Async::Loop->new;
$loop->add(my $t = Tickit::Async->new);
my $vbox = Tickit::Widget::VBox->new;
$vbox->add(my $dt = Tickit::Widget::Desktop->new(loop => $loop), expand => 1);
$loop->later(sub {
	$dt->create_panel(
		label => 'First',
		left => 4,
		top => 4,
		cols => 12,
		lines => 5,
	)->add(Tickit::Widget::Placegrid->new);
	$dt->create_panel(
		label => 'Second',
		left => 4,
		top => 14,
		cols => 18,
		lines => 5,
	)->add(Tickit::Widget::Placegrid->new);
});
$vbox->add(Tickit::Widget::Statusbar->new(loop => $loop));
$t->set_root_widget($vbox);
$t->run;

