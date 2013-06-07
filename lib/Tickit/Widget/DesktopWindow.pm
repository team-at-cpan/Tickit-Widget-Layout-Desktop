package Tickit::Widget::Desktop::Window;
use strict;
use warnings;
use parent qw(Tickit::WidgetRole::Movable Tickit::SingleChildWidget);

use Try::Tiny;

use Tickit::RenderContext qw(LINE_THICK LINE_SINGLE LINE_DOUBLE);
use Tickit::Utils qw(textwidth);
use Tickit::Style;

use constant CLEAR_BEFORE_RENDER => 0;

style_definition base =>
	fg => 'grey',
	linetype => 'round',
	maximise_fg => 'green',
	close_fg => 'red',
	title_fg => 'white';

style_definition ':active' =>
	fg => 'white',
	maximise_fg => 'hi-green',
	close_fg => 'hi-red',
	title_fg => 'hi-green';

sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new;
	Scalar::Util::weaken(
		$self->{container} = $args{container} or die "No container provided?"
	);
	$self;
}

=head2 position_is_maximise

Returns true if this location is the maximise button.

=cut

sub position_is_maximise {
	my ($self, $line, $col) = @_;
	my $win = $self->window or return;
	return 1 if $line == 0 && $col == $win->cols - 4;
	return 0;
}

=head2 position_is_close

Returns true if this location is the close button.

=cut

sub position_is_close {
	my ($self, $line, $col) = @_;
	my $win = $self->window or return;
	return 1 if $line == 0 && $col == $win->cols - 2;
	return 0;
}


=head2 mouse_press

Override mouse click events to mark this window as active
before continuing with the usual move/resize detection logic.

Provides click-to-raise and click-to-focus behaviour.

=cut

sub mouse_press {
	my $self = shift;
	my ($line, $col) = @_;
	$self->{container}->make_active($self);
	if($self->position_is_close($line, $col)) {
		# Close button... probably need some way to indicate when
		# this happens, Tickit::Window doesn't appear to have set_on_closed ?
		$self->window->clear;
		$self->window->close;
		return 1;
	} elsif($self->position_is_maximise($line, $col)) {
		my $win = $self->window or return 1;
		$win->change_geometry(
			0,
			0,
			$win->parent->lines,
			$win->parent->cols,
		);
		return 1;
	} else {
		$self->SUPER::mouse_press(@_)
	}
}

=head2 with_rc

Runs the given coderef with a L<Tickit::RenderContext>, saving
and restoring the context around the call.

Returns $self.

=cut

sub with_rc {
	my $self = shift;
	my $rc = shift;
	my $code = shift;
	$rc->save;
	$code->($rc);
	$rc->restore;
	$self;
}

=head2 render

Returns $self.

=cut

sub render {
	my $self = shift;
	my %args = @_;
	my $win = $self->window or return;

	my $rc = Tickit::RenderContext->new(
		lines => $win->lines,
		cols  => $win->cols,
	);
	$rc->clip($args{rect});

	# Use a default pen for drawing all the line-related pieces
	$rc->setpen($self->get_style_pen);

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
	my $text_pen = $self->get_style_pen('title');

	# This is a nasty hack - we want to know whether it's safe to draw
	# rounded corners, so we start by checking whether we have any line
	# cells already in place in the corners...
	my $tl = $rc->_xs_getcell( 0,  0)->state;
	my $tr = $rc->_xs_getcell( 0, $w)->state;
	my $bl = $rc->_xs_getcell($h,  0)->state;
	my $br = $rc->_xs_getcell($h, $w)->state;

	# ... then we render our actual border, possibly using a different style for
	# active window...
	my $line = {
		round => LINE_SINGLE,
		single => LINE_SINGLE,
		thick => LINE_THICK,
		double => LINE_DOUBLE,
	}->{$self->get_style_values('linetype')};
	$rc->hline_at( 0,  0, $w, $line);
	$rc->hline_at($h,  0, $w, $line);
	$rc->vline_at( 0, $h,  0, $line);
	$rc->vline_at( 0, $h, $w, $line);

	# ... and then we overdraw the corners, but only if we have
	# since active border is currently double lines and there's no
	# rounded equivalent there.
	if($self->get_style_values('linetype') eq 'round') {
		$rc->char_at( 0,  0, 0x256D) unless $tl == Tickit::RenderContext->LINE;
		$rc->char_at($h,  0, 0x2570) unless $bl == Tickit::RenderContext->LINE;
		$rc->char_at( 0, $w, 0x256E) unless $tr == Tickit::RenderContext->LINE;
		$rc->char_at($h, $w, 0x256F) unless $br == Tickit::RenderContext->LINE;
	}

	# Then the title
	my $txt = $self->format_label;
	$rc->text_at(0, (1 + $w - textwidth($txt)) >> 1, $txt, $text_pen);

	# and the icons for min/max/close, minimise isn't particularly useful so
	# let's not bother with that one.
	# $rc->text_at(0, $w - 3, "\N{U+238A}", Tickit::Pen->new(fg => 'hi-yellow'));
	$rc->text_at(0, $w - 3, "\N{U+25CE}", $self->get_style_pen('maximise'));
	$rc->text_at(0, $w - 1, "\N{U+2612}", $self->get_style_pen('close'));

	# Done - render and return
	$rc->flush_to_window($win);
}

sub format_label {
	my $self = shift;
	'[ ' . $self->label . ' ]';
}

sub render_frame {
	my $self = shift;
	my $rc = shift;
	my $target = shift;
	my $win = $self->window or return;

	my $line_type = LINE_SINGLE; # $self->is_active ? LINE_DOUBLE : LINE_SINGLE;

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

sub window_gained {
	my $self = shift;
	my ($win) = @_;
	delete $self->{frame_rects};
	$self->{window_lines} = $win->lines;
	$self->{window_cols} = $win->cols;
	return $self->SUPER::window_gained(@_);
}

sub reshape {
	my $self = shift;
	my $win = $self->window;

	# Keep our frame info if we're just moving the window around
	delete $self->{frame_rects} unless $self->{window_lines} == $win->lines && $self->{window_cols} == $win->cols;
	$self->{window_lines} = $win->lines;
	$self->{window_cols} = $win->cols;
	$self->set_child_window
}

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

sub mark_active {
	my $self = shift;
	$self->{active} = 1;
	$self->set_style_tag(active => 1);
	$self->expose_frame;
	$self
}

sub mark_inactive {
	my $self = shift;
	$self->{active} = 0;
	$self->set_style_tag(active => 0);
	$self->expose_frame;
	$self
}

# 'hmmm.'
sub expose_frame {
	my $self = shift;
	my $win = $self->window or return $self;
	$win->expose($_) for $self->frame_rects;
	$self;
}

sub frame_rects {
	my $self = shift;
	@{ $self->{frame_rects} ||= [
		Tickit::Rect->new(top => 0, left => 0, lines => 1, cols => $self->window->cols),
		Tickit::Rect->new(top => 0, left => 0, lines => $self->window->lines, cols => 1),
		Tickit::Rect->new(top => 0, left => $self->window->cols - 1, lines => $self->window->lines, cols => 1),
		Tickit::Rect->new(top => $self->window->lines - 1, left => 0, lines => 1, cols => $self->window->cols),
	] };
}

1;
