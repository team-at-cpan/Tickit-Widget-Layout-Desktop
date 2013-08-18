#!/usr/bin/env perl 
use strict;
use warnings;
package Tickit::Widget::Desktop::Window::Linked;
use parent qw(Tickit::Widget::Desktop::Window);

package main;
use IO::Async::Loop;
use Tickit::Async;
use Tickit::Widget::VBox;
use Tickit::Widget::Menubar;
use Tickit::Widget::Menubar::Item;
use Tickit::Widget::Desktop;
use Tickit::Widget::Statusbar;

#use Carp::Always;

my $loop = IO::Async::Loop->new;
$loop->add(my $tickit = Tickit::Async->new);
my $vbox = Tickit::Widget::VBox->new;

# Defer the setup until we have our terminal window, since we're not currently
# hooking the ::Desktop window allocation.
$loop->later(sub {
	$vbox->add(my $mb = Tickit::Widget::Menubar->new(
		popup_container => $vbox->window,
		linetype => 'single',
	));
	$vbox->add(my $desktop = Tickit::Widget::Desktop->new(loop => $loop), expand => 1);

	# None of these do anything since we're not providing any actions
	$mb->add_item(my $item = Tickit::Widget::Menubar::Item->new(label => '&File'));
	$item->add_item(Tickit::Widget::Menubar::Item->new(
		label => 'E&xit',
		on_activate => sub {
			$tickit->later(sub {
				$tickit->stop;
			})
		}
	));
	$mb->add_item($item = Tickit::Widget::Menubar::Item->new(label => '&Widgets'));

	$mb->add_item($item = Tickit::Widget::Menubar::Item->new(label => 'Win&dows'));
	$item->add_item(Tickit::Widget::Menubar::Item->new(
		label => '&Tile',
		on_activate => sub { $desktop->tile },
	));
	$item->add_item(Tickit::Widget::Menubar::Item->new(
		label => 'Ca&scade',
		on_activate => sub { $desktop->cascade }
	));
	$item->add_item(Tickit::Widget::Menubar::Item->new(
		label => 'Over&lapping tiles',
		on_activate => sub { $desktop->tile(overlap => 1) }
	));
	$item->add_item(Tickit::Widget::Menubar::Item->new(
		label => 'Close a&ll',
		on_activate => sub { $desktop->close_all }
	));
	$mb->add_item($item = Tickit::Widget::Menubar::Item::Separator->new, expand => 1);
	$mb->add_item($item = Tickit::Widget::Menubar::Item->new(label => '&Help'));
	$item->add_item(Tickit::Widget::Menubar::Item->new(
		label => '&About',
		on_activate => sub { }
	));
	$vbox->add(
		Tickit::Widget::Statusbar->new(loop => $loop)
	);
	$desktop->create_panel(
		subclass => 'Tickit::Widget::Desktop::Window::Linked',
		left => 4,
		top => 4,
		lines => 20,
		cols => 30,
		label => 'left',
	);
});
$tickit->set_root_widget($vbox);
$tickit->run;
