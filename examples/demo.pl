#!/usr/bin/env perl 
use strict;
use warnings;
use IO::Async::Loop;
use Tickit::Async;
use Tickit::Widget::VBox;
use Tickit::Widget::MenuBar;
use Tickit::Widget::Menu;
use Tickit::Widget::Menu::Item;
use Tickit::Widget::Desktop;
use Tickit::Widget::Statusbar;

use Tickit::Demo;
#use Carp::Always;

my $loop = IO::Async::Loop->new;
$loop->add(my $tickit = Tickit::Async->new);
my $vbox = Tickit::Widget::VBox->new;

# Defer the setup until we have our terminal window, since we're not currently
# hooking the ::Desktop window allocation.
#$loop->later(sub {
	$vbox->add(my $mb = Tickit::Widget::MenuBar->new(
		items => []
	));
	$vbox->add(my $desktop = Tickit::Widget::Desktop->new(loop => $loop), expand => 1);

	# None of these do anything since we're not providing any actions
	$mb->push_item(my $item = Tickit::Widget::Menu->new(name => '&File'));
	$item->push_item(Tickit::Widget::Menu::Item->new(
		name => 'E&xit',
		on_activate => sub {
			$tickit->later(sub {
				$tickit->stop;
			})
		}
	));
	$mb->push_item($item = Tickit::Widget::Menu->new(name => '&Widgets'));
	my $demo = Tickit::Demo->new(
		desktop => $desktop,
		tickit => $tickit,
		loop => $loop,
	);
	foreach my $plugin ($demo->plugins(demo => $demo)) {
		$item->push_item($plugin->menu_item($desktop));
	}
	$item->push_item(Tickit::Widget::Menu::Item->new(
		name => 'Show me everything',
		on_activate => sub {
			foreach my $plugin ($demo->plugins(demo => $demo)) {
				my $w = $plugin->widget or die "No widget for $plugin?";
				my $left = int($desktop->window->cols * rand);
				my $top = int($desktop->window->lines * rand);
				my $cols = 20 + int(10 * rand);
				my $lines = 5 + int(20 * rand);
				$left = $desktop->window->cols - $cols if $left + $cols >= $desktop->window->cols;
				$top = $desktop->window->lines - $lines if $top + $lines >= $desktop->window->lines;
				$desktop->create_panel(
					label => $plugin->label,
					left => $left,
					top => $top,
					cols => $cols,
					lines => $lines,
				)->add($w);
			}
		},
	));
	$mb->push_item($item = Tickit::Widget::Menu->new(name => 'Win&dows'));
	$item->push_item(Tickit::Widget::Menu::Item->new(
		name => '&Tile',
		on_activate => sub { $desktop->tile },
	));
	$item->push_item(Tickit::Widget::Menu::Item->new(
		name => 'Ca&scade',
		on_activate => sub { $desktop->cascade }
	));
	$item->push_item(Tickit::Widget::Menu::Item->new(
		name => 'Over&lapping tiles',
		on_activate => sub { $desktop->tile(overlap => 1) }
	));
	$item->push_item(Tickit::Widget::Menu::Item->new(
		name => 'Close a&ll',
		on_activate => sub { $desktop->close_all }
	));
#	$mb->push_item($item = Tickit::Widget::Menu::Item::Separator->new, expand => 1);
	$mb->push_item($item = Tickit::Widget::Menu->new(name => '&Help'));
	$item->push_item(Tickit::Widget::Menu::Item->new(
		name => '&About',
		on_activate => sub { }
	));
	$vbox->add(
		Tickit::Widget::Statusbar->new(loop => $loop)
	);
#});
$tickit->set_root_widget($vbox);
$tickit->run;
