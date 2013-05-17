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
use Tickit::Widget::Tree;
my $loop = IO::Async::Loop->new;
$loop->add(my $t = Tickit::Async->new);
my $vbox = Tickit::Widget::VBox->new;
$vbox->add(my $dt = Tickit::Widget::Desktop->new(loop => $loop), expand => 1);
$loop->later(sub {
	$dt->create_panel(
		label => 'First',
		left => 0,
		top => 0,
		cols => 30,
		lines => $dt->window->lines >> 1,
	)->add(Tickit::Widget::Placegrid->new);
	$dt->create_panel(
		label => 'Second',
		left => 29,
		top => 0,
		cols => $dt->window->cols - 29,
		lines => $dt->window->lines,
	)->add(Tickit::Widget::Placegrid->new);
	$dt->create_panel(
		label => 'Third',
		left => 0,
		top => ($dt->window->lines >> 1) - 1,
		cols => 30,
		lines => $dt->window->lines - (($dt->window->lines >> 1) - 1),
	)->add(Tickit::Widget::Tree->new);
});
#$vbox->add(Tickit::Widget::Statusbar->new(loop => $loop));
$t->set_root_widget($vbox);
$t->run;

