package Tickit::Widget::Countdown;
use strict;
use warnings;
use parent qw(Tickit::Widget);
use curry::weak;
use Time::HiRes ();
use POSIX qw(floor strftime);
use IO::Async::Timer::Periodic;

use constant CLEAR_BEFORE_RENDER => 0;

use Tickit::Render::Truetype;

sub lines { 1 }
sub cols { 1 }

sub new {
	my $class = shift;
	my %args = @_;
	my $txt = delete $args{text};
	my $font = delete $args{font};
	my $loop = delete $args{loop};
	my $self = $class->SUPER::new(%args);
	$self->{text} = $txt // '';
	$self->{font} = $font;
	my $now = Time::HiRes::time;
	$self->{target} = $now + 120;
	$loop->add($self->{timer} = IO::Async::Timer::Periodic->new(
		interval => 1.00,
		reschedule => 'skip',
		first_interval => 0.01 + ($now - floor($now)),
		on_tick => $self->curry::weak::redraw,
	));
	$self->{timer}->start;
	$self
}

sub render {
	my $self = shift;
	my %args = @_;
	my $win = $self->window or return;
	my $rc = Tickit::RenderContext->new(
		lines => $win->lines,
		cols  => $win->cols,
	);
	$rc->clip($args{rect});
	$rc->clear($self->pen);

	my $ttf = Tickit::Render::Truetype->new;
	$ttf->set_font($self->font);
	my $now = Time::HiRes::time;
	$ttf->render_text(
		$rc,
		text => strftime('%H:%M:%S', gmtime($self->{target} - $now)),
		pen => $self->pen,
		size => 48,
	);
	$rc->flush_to_window($win);
}

sub font { shift->{font} }

sub set_text {
	my $self = shift;
	$self->{text} = shift // '';
	$self->redraw;
}

1;
