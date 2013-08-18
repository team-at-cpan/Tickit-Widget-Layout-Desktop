package Tickit::DSL;
use strict;
use warnings;
use parent qw(Exporter);

use Tickit::Widget::VBox;
use Tickit::Widget::HBox;
use Tickit::Widget::Static;
use Tickit::Widget::Entry;
use Tickit::Widget::Scroller;
use Tickit::Widget::Scroller::Item::Text;
use Tickit::Widget::Statusbar;
use Tickit::Widget::Tabbed;
use Tickit::Widget::Menubar;
use Tickit::Widget::Menubar::Item;
use Tickit::Widget::Menubar::Item::Separator;
use Tickit::Async;
use IO::Async::Loop;

our $PARENT;
our $TICKIT;
our $LOOP;
our @WIDGET_ARGS;

our @EXPORT = our @EXPORT_OK = qw(
	tickit
	widget
	vbox hbox
	static entry
	scroller scroller_text
	tabbed
	statusbar
	menubar submenu menuitem menuspacer
);

sub tickit { $TICKIT = shift if @_; $TICKIT ||= Tickit::Async->new }
sub loop { $LOOP = shift if @_; $LOOP ||= IO::Async::Loop->new }

sub vbox(&@) {
	my ($code, %args) = @_;
	my $w = Tickit::Widget::VBox->new;
	{
		local $PARENT = $w;
		$code->($w);
	}
	apply_widget($w);
}

sub hbox(&@) {
	my ($code, %args) = @_;
	my $w = Tickit::Widget::HBox->new;
	{
		local $PARENT = $w;
		$code->($w);
	}
	apply_widget($w);
}

sub scroller(&@) {
	my ($code, %args) = @_;
	my $w = Tickit::Widget::Scroller->new;
	{
		local $PARENT = $w;
		$code->($w);
	}
	apply_widget($w);
}

sub scroller_text {
	my $w = Tickit::Widget::Scroller::Item::Text->new(shift // '');
	apply_widget($w);
}

sub tabbed(&@) {
	my ($code, %args) = @_;
	my $w = Tickit::Widget::Tabbed->new;
	{
		local $PARENT = $w;
		$code->($w);
	}
	apply_widget($w);
}

sub statusbar(&@) {
	my ($code, %args) = @_;
	my $w = Tickit::Widget::Statusbar->new(loop => loop);
	{
		local $PARENT = $w;
		$code->($w);
	}
	apply_widget($w);
}

sub widget(&@) {
	my ($code, @args) = @_;
	local @WIDGET_ARGS = @args;
	my %args = @args;
	local $PARENT = $args{parent} || $PARENT;
	$code->($PARENT);
}

sub static {
	my %args = (text => @_);
	$args{text} //= '';
	my $w = Tickit::Widget::Static->new(
		%args
	);
	apply_widget($w);
}

sub entry(&@) {
	my %args = (on_enter => @_);
	my $w = Tickit::Widget::Entry->new(
		%args
	);
	apply_widget($w);
}

sub menubar(&@) {
	my ($code, %args) = @_;
	my $w = Tickit::Widget::Menubar->new;
	{
		local $PARENT = $w;
		$code->($w);
	}
	apply_widget($w);
}

sub submenu {
	my ($text, $code) = splice @_, 0, 2;
	my $w = Tickit::Widget::Menubar::Item->new(label => $text);
	{
		local $PARENT = $w;
		$code->($w);
	}
	apply_widget($w);
}

sub menuspacer() {
	my $w = Tickit::Widget::Menubar::Item::Separator->new;
	local @WIDGET_ARGS = (expand => 1);
	apply_widget($w);
}

sub menuitem {
	my ($text, $code) = splice @_, 0, 2;
	my $w = Tickit::Widget::Menubar::Item->new(
		label => $text,
		on_activate => $code,
	);
	apply_widget($w);
}

sub apply_widget {
	my $w = shift;
	if($PARENT) {
		if($PARENT->isa('Tickit::Widget::Scroller')) {
			$PARENT->push($w);
		} elsif($PARENT->isa('Tickit::Widget::Menubar::Item')) {
			$PARENT->add_item($w, @WIDGET_ARGS);
		} elsif($PARENT->isa('Tickit::Widget::Menubar::Vertical')) {
			$PARENT->add_item($w, @WIDGET_ARGS);
		} elsif($PARENT->isa('Tickit::Widget::Menubar::Horizontal')) {
			$PARENT->add_item($w, @WIDGET_ARGS);
		} else {
			$PARENT->add($w, @WIDGET_ARGS);
		}
	} else {
		tickit->set_root_widget($w);
	}
	$w
}

1;
