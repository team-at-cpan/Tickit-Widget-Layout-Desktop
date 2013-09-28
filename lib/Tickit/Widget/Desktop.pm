package Tickit::Widget::Desktop;
use strict;
use warnings;
use parent qw(Tickit::Widget);

=pod


Constructed of:

=over 4

=item * ::Desktop::Window - the window implementation

=item * ::Desktop - background desktop on which the
floats are displayed

=item * ::Desktop::Taskbar - a subclass of statusbar which provides
window lists and launchers (maybe)

=back


=cut

use curry::weak;
use Scalar::Util qw(refaddr);
use List::Util qw(max);
use Tickit::Utils qw(textwidth distribute);
use Tickit::Widget::Desktop::Window;

use constant CLEAR_BEFORE_RENDER => 0;

sub lines { 1 }
sub cols { 1 }

=head2 render

Clears the exposed area. All rendering happens in the
floating windows on top of this widget.

=cut

sub render {
	my $self = shift;
	my %args = @_;
	my $win = $self->window or return;
	$win->clearrect($args{rect});
}

=head2 overlay

Render all window outlines on top of the target widget.

Takes the following parameters:

=over 4

=item * $rb - the L<Tickit::RenderBuffer> we will be drawing into

=item * $exclude - the current L<Tickit::Widget> we are drawing - this will be used
to check for intersections so we don't waste time drawing unrelated areas

=back

=cut

sub overlay {
	my $self = shift;
	my $rb = shift;
	my $exclude = shift;
	my $target = $exclude->window->rect;

	# TODO change this when proper accessors are available
	my %win_map = map {
		refaddr($_->window) => $_
	} @{$self->{widgets}};
	delete $win_map{refaddr($exclude->window)};

	# Each child widget, from back to front
	foreach my $child (reverse grep defined, map $win_map{refaddr($_)}, @{$self->window->{child_windows}}) {
		my $w = $child->window or next;
		next unless $w->rect->intersects($target);

		# Clear out anything that would be under this window,
		# so we don't draw lines that are obscured by upper
		# layers
		for my $l ($w->top..$w->bottom - 1) {
			$rb->erase_at($l, $w->left + 1, $w->cols - 2);
		}

		# Let the child window render itself to the given
		# context, since it knows more about styles than we do
		$child->render_frame($rb, $target);
	}
}

=head2 window_gained

Records our initial window geometry when the L<Tickit::Window> is first attached.

=cut

sub window_gained {
	my $self = shift;
	my ($win) = @_;
	$self->{geometry} = {
		map { $_ => $win->$_ } qw(top left lines cols)
	};
	$self->SUPER::window_gained(@_);

}

sub loop { shift->{loop} }

=head2 create_panel

Creates a L<Tickit::Widget::Desktop::Window> on this L<Tickit::Widget::Desktop>.

Takes the following named parameters:

=over 4

=item * top - offset from top of desktop

=item * left - offset from desktop left margin

=item * lines - how many lines the new widget will have, should be >2 to display anything useful

=item * cols - how many columns the new widget will have, should be >2 to display anything useful

=item * label - what label to use, default is the uninspiring text C<window>

=back

=cut

sub create_panel {
	my $self = shift;
	my %args = @_;
	my $win = $self->window or return;

	my $float = $win->make_float(
		$args{top},
		$args{left},
		$args{lines},
		$args{cols},
	);

	my $w = ($args{subclass} || 'Tickit::Widget::Desktop::Window')->new(
		container => $self,
	);
	$w->label($args{label} // 'window');
	$w->set_window($float);
	push @{$self->{widgets}}, $w;

	# Need to redraw our window if position or size change
	$self->{extents}{refaddr $float} = $float->rect;
	$float->set_on_geom_changed($self->curry::weak::float_geom_changed($w));
	$w
}

sub float_geom_changed {
	my $self = shift;
	my $w = shift;
	my $win = $self->window or return;
	my $float = $w->window or return;

	my $old = $self->{extents}{refaddr $float};
	# Any time a panel moves or changes size, we'll potentially need
	# to trigger expose events on the desktop background and any
	# sibling windows.
	# Start by working out what part of our current desktop
	# has just been uncovered, and fire expose events at our top-level
	# window for this area (for a move, it'll typically be up to two rectangles)
	# area covered by the 
	my $rs = Tickit::RectSet->new;
	$rs->add($old);
	$rs->subtract($w->window->rect);
	# Originally thought we might need expose events for the newly-covered
	# area as well, but that does not seem to be necessary.
	# $rs->add($w->window->rect);
	# $rs->subtract($old->intersect($w->window->rect));
	$win->expose($_) for $rs->rects;
	# This was an experiment which really didn't work out. Seems logical that shifting the
	# area around would be more efficient, but it's not like many terminals appear to support
	# arbitrary rectangular scrolling anyway.
	if(1) {
		my $wr = $w->window->rect;
		if($old->lines == $wr->lines && $old->cols == $wr->cols) {
			# Tickit::Window;
			my $down = ($wr->top - $old->top);
			my $right = ($wr->left - $old->left);
			warn sprintf '(%d,%d), %dx%d for %dx%d', $wr->left, $wr->top, $wr->cols, $wr->lines, $right, $down;
			$win->scrollrect(
				$wr->top,
				$wr->left,
				$wr->lines,
				$wr->cols,
				$down,
				$right,
			) && $w->window->scrollrect(
				0, #$wr->top,
				0, #$wr->left,
				$wr->lines,
				$wr->cols,
				$down,
				$right,
			) or do { warn "no scrolling :("; $w->window->expose($_) for $rs->rects };
			$w->expose_frame;
		} else {
			$w->window->expose;
		}
	}

	# Mark the entire child window as exposed. Hopefully we can cut
	# this down in future.
	# FIXME We've marked the top-level (desktop) window as exposed for all the changed areas,
	# so surely that would propagate to any relevant areas on the child windows? seems that
	# this line really should not be needed if the above RectSet calculations were done
	# correctly.
#	$w->window->expose;

	# After all that we can stash the current extents for this child window
	# so we know what's changed next time.
	$self->{extents}{refaddr $float} = $w->window->rect;

	# Do remember to pass on the event so the child widget knows what's going on
	$w->reshape(@_);
}

=head1 API METHODS

These methods are provided as an API for the L<Tickit::Widget::Desktop::Window> children.
They allow widgets to interact with the desktop for requesting focus etc.

=head2 make_active

Makes the requested L<Tickit::Widget::Desktop::Window> active - brings it to the front of
the stack and gives it focus.

Returns $self.

=cut

sub make_active {
	my $self = shift;
	my $child = shift;
	$_->mark_inactive for grep $_->is_active, @{$self->{widgets}};
	$child->window->raise_to_front;
	$child->mark_active;
}

sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new;
	Scalar::Util::weaken(
		$self->{loop} = $args{loop} or die "No loop provided?"
	);
	$self;
}

=head2 reshape

Deal with reshape requests.

Since our windows are positioned directly, we're going to lose some information if shrink
then expand the parent window again. This isn't ideal but hopefully we can get away with
it for now.

Returns $self.

=cut

sub reshape {
	my $self = shift;
	my $win = $self->window or return;

	my @directions = qw(top left lines cols);

	my $lines_ratio = $self->{geometry}{lines} ? $win->lines / $self->{geometry}{lines} : 1;
	my $cols_ratio = $self->{geometry}{cols} ? $win->cols / $self->{geometry}{cols} : 1;

	# First, get all the sizes across all widgets
	foreach my $w (@{$self->{widgets}}) {
		my $subwin = $w->window or next;
		$w->window->change_geometry(
			(map int, 
				$subwin->top * $lines_ratio,
				$subwin->left * $cols_ratio),
			(map int($_) || 1,
				$subwin->lines * $lines_ratio,
				$subwin->cols * $cols_ratio)
		);
	}
	$self->{geometry} = { map { $_ => $win->$_ } @directions };

#	my %buckets = map { $_ => [] } @directions;
#	foreach my $w (@{$self->{widgets}}) {
#		push @{$buckets{$_}}, { base => $w->window->$_, expand => 1 } for @directions;
#	}
#
#	# Now recalculate the distribution
#	distribute($win->lines, @{$buckets{top}});
#	distribute($win->lines, @{$buckets{lines}});
#	distribute($win->cols, @{$buckets{left}});
#	distribute($win->cols, @{$buckets{cols}});
#	use Data::Dumper;
#	warn Dumper(\%buckets);
#
#	# Then we apply the new sizes back to the widgets
#	foreach my $w (@{$self->{widgets}}) {
#		$w->window->change_geometry(
#			map { (shift @{$buckets{$_}})->{value} } @directions,
#		)
#	}
}

sub cascade {
	my $self = shift;
	my @windows = reverse @{$self->window->{child_windows}};
	my $x = 0;
	my $y = 0;
	my $lines = $self->window->lines - @windows;
	$lines = 6 if $lines < 6;
	my $cols = $self->window->cols - @windows;
	$cols = 6 if $cols < 6;
	$_->change_geometry($y++, $x++, $lines, $cols) for @windows;
	$self
}

=head2 tile

Tiles all the windows. Tries to lay them out so things don't overlap.
Since we're resizing, things may end up ridiculously small.

Pass overlap => 1 to have overlapping edges.

Returns $self.

=cut

sub tile {
	my $self = shift;
	my %args = @_;
	my $win = $self->window or return;
	my @windows = reverse @{$win->{child_windows}};

	# Try to end up with something vaguely square. Probably a bad
	# choice but it seems tolerable for the moment.
	my $side = int(sqrt 0+@windows) || 1;

	# Find the tallest window in each grid row for distribution
	my @lines;
	{
		my @rows = @windows;
		while(@rows) {
			my @batch = splice @rows, 0, $side;
			push @lines, +{ expand => 1, base => max map $_->lines, @batch };
		}
		distribute($win->lines, @lines);
		if($args{overlap}) { # haxx
			++$_->{value} for @lines;
			--$lines[-1]{value};
		}
	}

	# Now step through all the windows, handling one row at a time
	while(@windows) {
		my @batch = splice @windows, 0, $side;
		my $l = shift @lines;
		my @cols  = map +{ base => $_->cols, expand => 1}, @batch;
		distribute($win->cols, @cols);
		if($args{overlap}) { # haxx
			++$_->{value} for @cols;
			--$cols[-1]{value};
		}
		foreach my $w (@batch) {
			my $c = shift @cols;
			$w->change_geometry($l->{start}, $c->{start}, $l->{value}, $c->{value});
		}
	}
}

sub close_all {
	my $self = shift;
	$_->close for reverse @{$self->window->{child_windows}};
}

1;
