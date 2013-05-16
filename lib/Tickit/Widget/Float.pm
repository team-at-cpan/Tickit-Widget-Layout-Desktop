package Tickit::Widget::Float;
use strict;
use warnings;
use parent qw(Tickit::WidgetRole::Movable Tickit::SingleChildWidget);
use Try::Tiny;

use Tickit::RenderContext qw(LINE_THICK LINE_SINGLE LINE_DOUBLE);
use Tickit::Utils qw(textwidth);

use constant CLEAR_BEFORE_RENDER => 0;

sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new;
	Scalar::Util::weaken(
		$self->{container} = $args{container} or die "No container provided?"
	);
	$self;
}

sub mouse_press {
	my $self = shift;
	$self->{container}->make_active($self);
	$self->SUPER::mouse_press(@_)
}

sub with_rc {
	my $self = shift;
	my $rc = shift;
	my $code = shift;
	$rc->save;
	$code->($rc);
	$rc->restore;
	$self;
}

sub render {
	my $self = shift;
	my %args = @_;
	my $win = $self->window or return;

	# We're going 
	my $rc = Tickit::RenderContext->new(
		lines => $win->lines,
		cols  => $win->cols,
	);
	$rc->clip($args{rect});

	# Use a default pen for drawing all the line-related pieces
	$rc->setpen($self->is_active ? Tickit::Pen->new(fg => 'white') : Tickit::Pen->new(fg => 'grey'));

	# $rc->clear(Tickit::Pen->new(fg => 'white'));

	# First, work out any line intersections for our border.
	$self->with_rc($rc => sub {
		my $rc = shift;

		# We'll be rendering relative to the container
		$rc->translate(-$win->top, -$win->left);

		# Ask our container to ask all other floating
		# windows to render their frames on our context,
		# so we join line segments where expected
		$self->{container}->overlay($rc => $self);

		# Restore our origin
		# TODO would've thought ->restore should handle this?
		$rc->translate( $win->top,  $win->left);
	});

	my ($w, $h) = map $win->$_ - 1, qw(cols lines);
# Tickit::Style
	my $text_pen = Tickit::Pen->new(fg => $self->is_active ? 'hi-green' : 'white');

	# This is a nasty hack - we want to know whether it's safe to draw
	# rounded corners, so we start by checking whether we have any line
	# cells already in place in the corners...
	my $tl = $rc->_xs_getcell( 0,  0)->state;
	my $tr = $rc->_xs_getcell( 0, $w)->state;
	my $bl = $rc->_xs_getcell($h,  0)->state;
	my $br = $rc->_xs_getcell($h, $w)->state;

	# ... then we render our actual border, using a different style for
	# active window...
	my $line = $self->is_active ? LINE_DOUBLE : LINE_SINGLE;
	my $pen = $self->is_active ? Tickit::Pen->new(fg => 'white') : undef;
	$rc->hline_at( 0,  0, $w, $line, $pen);
	$rc->hline_at($h,  0, $w, $line, $pen);
	$rc->vline_at( 0, $h,  0, $line, $pen);
	$rc->vline_at( 0, $h, $w, $line, $pen);

	# ... and then we overdraw the corners, but only if we're inactive,
	# since active border is currently double lines and there's no
	# rounded equivalent there.
	unless($self->is_active) {
		$rc->char_at( 0,  0, 0x256D, $pen) unless $tl == Tickit::RenderContext->LINE;
		$rc->char_at($h,  0, 0x2570, $pen) unless $bl == Tickit::RenderContext->LINE;
		$rc->char_at( 0, $w, 0x256E, $pen) unless $tr == Tickit::RenderContext->LINE;
		$rc->char_at($h, $w, 0x256F, $pen) unless $br == Tickit::RenderContext->LINE;
	}

	# Then the title
	my $txt = ' ' . $self->label . ' ';
	$rc->text_at(0, (1 + $w - textwidth($txt)) >> 1, $txt, $text_pen);

	# and the icons for min/max/close
	$rc->text_at(0, $w - 3, "\N{U+238A}", Tickit::Pen->new(fg => 'hi-yellow'));
	$rc->text_at(0, $w - 2, "\N{U+25CE}", Tickit::Pen->new(fg => 'hi-green'));
	$rc->text_at(0, $w - 1, "\N{U+2612}", Tickit::Pen->new(fg => 'hi-red'));

	# Done - render and return
	$rc->flush_to_window($win);
}

sub render_frame {
	my $self = shift;
	my $rc = shift;
	my $target = shift;
	my $win = $self->window or return;

	my $line_type = $self->is_active ? LINE_DOUBLE : LINE_SINGLE;

	if($win->left < $target->left) {
		$rc->hline_at($win->top, $win->left, $target->left, $line_type);
		$rc->hline_at($win->bottom - 1, $win->left, $target->left, $line_type);
	}
	if($win->right > $target->right) {
		$rc->hline_at($win->top, $target->right - 1, $win->right - 1, $line_type);
		$rc->hline_at($win->bottom - 1, $target->right - 1, $win->right - 1, $line_type);
	}
	if($win->top < $target->top) {
		$rc->vline_at($win->top, $target->top, $win->left, $line_type);
		$rc->vline_at($win->top, $target->top, $win->right - 1, $line_type);
	}
	if($win->bottom > $target->bottom) {
		$rc->vline_at($target->bottom - 1, $win->bottom - 1, $win->left, $line_type);
		$rc->vline_at($target->bottom - 1, $win->bottom - 1, $win->right - 1, $line_type);
	}

	my $txt = ' ' . $self->label . ' ';
	$rc->text_at($win->left, $win->top + (($win->cols - textwidth($txt)) >> 1), $txt);
}

sub is_active { shift->{active} ? 1 : 0 }

sub label {
	my $self = shift;
	return $self->{label} // '' unless @_;
	$self->{label} = shift;
	return $self;
}

sub lines {
	my $self = shift;
	my $child = $self->child;
	return 2 + ($child ? $child->lines : 0);
}

sub cols {
	my $self = shift;
	my $child = $self->child;
	return 2 + ($child ? $child->cols : 0);
}

sub children_changed { shift->set_child_window }
sub reshape { shift->set_child_window }

sub set_child_window {
   my $self = shift;

   my $window = $self->window or return;
   my $child  = $self->child  or return;

   my $lines = $window->lines;
   my $cols  = $window->cols;

   if( $lines > 2 and $cols > 2 ) {
      if( my $childwin = $child->window ) {
         $childwin->change_geometry( 1, 1, $lines - 2, $cols - 2 );
      }
      else {
         my $childwin = $window->make_sub( 1, 1, $lines - 2, $cols - 2 );
         $child->set_window( $childwin );
      }
   }
   else {
      if( $child->window ) {
         $child->set_window( undef );
      }
   }
}

1;
