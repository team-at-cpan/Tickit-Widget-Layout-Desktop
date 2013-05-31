#!/usr/bin/env perl 
use strict;
use warnings;
use IO::Async::Loop;
use Tickit::Async;
use Tickit::Widget::VBox;
use Tickit::Widget::Menubar;
use Tickit::Widget::Menubar::Item;
use Tickit::Widget::Desktop;
use Tickit::Widget::Statusbar;

use Tickit::Demo;

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
	$mb->add_item(my $item = Tickit::Widget::Menubar::Item->new(label => 'File'));
	$item->add_item(Tickit::Widget::Menubar::Item->new(
		label => 'Exit',
		on_activate => sub {
			$tickit->later(sub {
				$tickit->stop;
			})
		}
	));
	$mb->add_item($item = Tickit::Widget::Menubar::Item->new(label => 'Widgets'));
	my $demo = Tickit::Demo->new(
		desktop => $desktop,
		tickit => $tickit,
		loop => $loop,
	);
	foreach my $plugin ($demo->plugins(demo => $demo)) {
		$item->add_item($plugin->menu_item($desktop));
	}
	$item->add_item(Tickit::Widget::Menubar::Item->new(
		label => 'Show me everything',
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
	$mb->add_item($item = Tickit::Widget::Menubar::Item::Separator->new, expand => 1);
	$mb->add_item($item = Tickit::Widget::Menubar::Item->new(label => 'Help'));
	$item->add_item(Tickit::Widget::Menubar::Item->new(
		label => 'About',
		on_activate => sub { }
	));
	$vbox->add(
		Tickit::Widget::Statusbar->new(loop => $loop)
	);
});
$tickit->set_root_widget($vbox);
$tickit->run;
