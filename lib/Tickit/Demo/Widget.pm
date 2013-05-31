package Tickit::Demo::Widget;
use strict;
use warnings;
use curry;
use Scalar::Util;

sub new { my $class = shift; bless { @_ }, $class }

sub tickit { shift->{demo}->tickit }
sub desktop { shift->{demo}->desktop }
sub loop { shift->{demo}->loop }

sub label { die "No label provided for @_" }
sub widget { die "No widget method provided for @_" }

sub menu_item {
	my $class = shift;
	my $desktop = shift;
	Scalar::Util::weaken($desktop);
	Tickit::Widget::Menubar::Item->new(
		label => $class->label,
		on_activate => sub { $class->create($desktop) },
	);
}

sub create {
	my $class = shift;
	my $desktop = shift;
	my $w = $class->widget or die "No widget for @_?";
	$desktop->create_panel(
		label => $class->label,
		left => 3,
		top => 3,
		cols => 30,
		lines => 1 + ($desktop->window->lines >> 2),
	)->add($w);
}

1;
