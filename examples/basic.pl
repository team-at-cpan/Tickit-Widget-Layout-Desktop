#!/usr/bin/env perl
use strict;
use warnings;
use IO::Async::Loop;
use Tickit::Async;
use Tickit::Widget::VBox;
use Tickit::Widget::Layout::Desktop;

my $loop = IO::Async::Loop->new;
$loop->add(my $tickit = Tickit::Async->new);
my $vbox = Tickit::Widget::VBox->new;

$vbox->add(
	my $desktop = Tickit::Widget::Layout::Desktop->new(
		loop => $loop
	),
	expand => 1
);

my @labels = ("First widget", "Second widget");
for my $w (Tickit::Widget::Placegrid->new, Tickit::Widget::Static->new(label => 'simple text widget')) {
	my $left = int($desktop->window->cols * rand);
	my $top = int($desktop->window->lines * rand);
	my $cols = 20 + int(10 * rand);
	my $lines = 5 + int(20 * rand);
	$left = $desktop->window->cols - $cols if $left + $cols >= $desktop->window->cols;
	$top = $desktop->window->lines - $lines if $top + $lines >= $desktop->window->lines;
	$desktop->create_panel(
		label => shift(@labels),
		left => $left,
		top => $top,
		cols => $cols,
		lines => $lines,
	)->add($w);
}
$tickit->set_root_widget($vbox);
$tickit->run;
