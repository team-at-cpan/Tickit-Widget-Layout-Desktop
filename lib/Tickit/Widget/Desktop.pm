package Tickit::Widget::Desktop;
use strict;
use warnings;
use parent qw(Tickit::Widget);

=pod


Constructed of:

=over 4

=item * Float - the window implementation

=item * Float::Close - close button

=item * Float::Maximise - max button

=item * Float::Minimise - max button

=item * Desktop - background desktop on which the
floats are displayed

=item * Taskbar - a subclass of statusbar which provides
window lists and launchers

=back


=cut

use curry::weak;
use Scalar::Util qw(refaddr);
use Tickit::Utils qw(textwidth);
use Tickit::Widget::Float;

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

=cut

sub overlay {
	my $self = shift;
	my $rc = shift;
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
			$rc->erase_at($l, $w->left + 1, $w->cols - 2);
		}

		# Let the child window render itself to the given
		# context, since it knows more about styles than we do
		$child->render_frame($rc, $target);
	}
}

sub window_gained {
	my $self = shift;
	my ($win) = @_;
	$self->SUPER::window_gained(@_);

}

sub loop { shift->{loop} }

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

	my $w = Tickit::Widget::Float->new(
		container => $self,
	);
	$w->label($args{label} // 'A window');
	$w->set_window($float);
	push @{$self->{widgets}}, $w;

	# Need to redraw our window if position or size change
	Scalar::Util::weaken($w);

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
	# This was an experiment which really didn't work out.
	if(0) {
		if($old->lines == $w->window->rect->lines && $old->cols == $w->window->rect->cols) {
			$win->scrollrect(
				$w->window->top,
				$w->window->left,
				$w->window->lines,
				$w->window->cols,
				$w->window->top - $old->top,
				$w->window->left - $old->left,
			) or do { $w->window->expose($_) for $rs->rects };
		} else {
			$w->window->expose;
		}
	}

	# Mark the entire child window as exposed. Hopefully we can cut
	# this down in future.
	$w->window->expose;

	# After all that we can stash the current extents for this child window
	# so we know what's changed next time.
	$self->{extents}{refaddr $float} = $w->window->rect;

	$w->reshape(@_);
}

#Tickit::Window

sub window_lost {
	my $self = shift;
	my $win = shift;
}

sub make_active {
	my $self = shift;
	my $child = shift;
	foreach my $w (@{$self->{widgets}}) {
		$w->redraw if $w->is_active;
		$w->{active} = 0;
	}
	$child->{active} = 1;
	$child->window->raise_to_front;
	$child->redraw;
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

sub reshape {
	my $self = shift;
	my $win = $self->window or return;

}

1;
