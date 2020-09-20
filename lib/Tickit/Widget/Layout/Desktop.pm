package Tickit::Widget::Layout::Desktop;
# ABSTRACT: desktop-like float management implementation for Tickit
use strict;
use warnings;

use utf8;

use parent qw(Tickit::ContainerWidget);

our $VERSION = '0.012';
# AUTHORITY

=head1 NAME

Tickit::Widget::Layout::Desktop - provides a holder for "desktop-like" widget behaviour

=head1 SYNOPSIS

# EXAMPLE: examples/synopsis.pl

=head1 DESCRIPTION

Experimental release for a container that provides move/resize/minimize/maximize "window" behaviour.

=begin HTML

<p><img src="http://tickit.perlsite.co.uk/cpan-screenshot/tickit-widget-layout-desktop1.gif" alt="Desktop widget in action" width="539" height="315"></p>

=end HTML

Constructed of:

=over 4

=item * L<Tickit::Widget::Layout::Desktop::Window> - the window implementation

=item * this class - background desktop on which the floats are displayed

=back

and maybe later:

=over 4

=item * ::Desktop::Taskbar - a subclass of statusbar which provides
window lists and launchers

=back

=cut

use curry::weak;
use Scalar::Util qw(refaddr);
use List::Util qw(max pairmap);
use Tickit::Utils qw(textwidth distribute);

use Tickit::Widget::Menu;
use Tickit::Widget::Menu::Item;

use Tickit::Widget::Layout::Desktop::Window;
use Variable::Disposition;

use constant CAN_FOCUS => 1;
use constant WIDGET_PEN_FROM_STYLE => 1;
#use Tickit::ContainerWidget

=head1 METHODS

=cut

sub lines { 1 }
sub cols { 1 }

=head2 render_to_rb

Clears the exposed area. All rendering happens in the
floating windows on top of this widget.

=cut

sub render_to_rb {
    my ($self, $rb, $rect) = @_;
    $rb->eraserect($rect);
}

sub children { @{shift->{widgets}} }

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
    my ($self, $rb, $rect, $exclude) = @_;
    my $target = $exclude->window->rect;

    # TODO change this when proper accessors are available
    my %win_map = map {
        refaddr($_->window) => $_
    } @{$self->{widgets}};
    delete $win_map{refaddr($exclude->window)};

    # Each child widget, from back to front
    CHILD:
    foreach my $child (reverse grep defined, map $win_map{refaddr($_)}, $self->window->subwindows) {
        next CHILD unless my $w = $child->window;
        next CHILD unless $w->rect->intersects($target);

        # Clear out anything that would be under this window,
        # so we don't draw lines that are obscured by upper
        # layers
        $rb->eraserect(
            $w->rect
        );

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

=head2 create_panel

Creates a L<Tickit::Widget::Layout::Desktop::Window> on this L<Tickit::Widget::Layout::Desktop>.

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

    # Normalise percentages
    $args{$_} = $self->horizontal($win, $args{$_}) for grep exists $args{$_}, qw(left right cols);
    $args{$_} = $self->vertical($win, $args{$_})   for grep exists $args{$_}, qw(top bottom lines);

    $args{bottom} = $win->lines - $args{bottom} if exists $args{bottom};
    $args{right} = $win->cols - $args{right} if exists $args{right};

    if(defined(my $bottom = delete $args{bottom})) {
        # Extrapolate coördinates to ensure we have top+lines
        $args{top}   //= $bottom - $args{lines} if exists $args{lines};
        $args{lines} //= $bottom - $args{top} if exists $args{top};
    }

    if(defined(my $right = delete $args{right})) {
        # Extrapolate coördinates to ensure we have left+cols
        $args{left}  //= $right - $args{cols} if exists $args{cols};
        $args{cols}  //= $right - $args{left} if exists $args{left};
    }

    $args{top} //= 2;
    $args{left} //= 2;
    $args{lines} ||= 10;
    $args{cols} ||= 10;

    my $float = $win->make_float(
        $args{top},
        $args{left},
        $args{lines},
        $args{cols},
    );
    $float->cursor_at(0,0);

    my $w = ($args{subclass} || 'Tickit::Widget::Layout::Desktop::Window')->new(
        container => $self,
    );
    $w->label($args{label} // 'window');
    $w->set_window($float);
    push @{$self->{widgets}}, $w;

    # Need to redraw our window if position or size change
    $self->{extents}{refaddr $float} = $float->rect->translate(0,0);
    $float->bind_event(geomchange => $self->curry::weak::float_geom_changed($w));
    $w
}

sub horizontal {
    my ($self, $win, $v) = @_;
    $v = $1 * $win->cols if $v =~ /(-?\d+(?:\.\d*)?)%/;
    $v
}

sub vertical {
    my ($self, $win, $v) = @_;
    $v = $1 * $win->lines if $v =~ /(-?\d+(?:\.\d*)?)%/;
    $v
}

sub show_control {
    my ($self, $panel, @items) = @_;
    my $win = $self->window or return;
    my $panel_win = $panel->window;

    my $menu;
    my @menu_items = pairmap {
        { # https://rt.cpan.org/Ticket/Display.html?id=95409
            my $code = $b;
            Tickit::Widget::Menu::Item->new(
                name => $a,
                on_activate => sub {
                    $menu->dismiss;
                    $win->tickit->later(sub {
                        $code->();
                        dispose $menu;
                    });
                }
            )
        }
    } @items;

    $menu = Tickit::Widget::Menu->new(
        items => \@menu_items,
    );
    $menu->popup(
        $panel_win,
        1,
        1
    );
}

sub float_geom_changed {
    my $self = shift;
    my $w = shift;
    my $win = $self->window or return;
    my $float = $w->window or return;

    my $old = $self->{extents}{refaddr $float};
    my $new = $float->rect;

    # Any time a panel moves or changes size, we'll potentially need
    # to trigger expose events on the desktop background and any
    # sibling windows.
    # Start by working out what part of our current desktop
    # has just been uncovered, and fire expose events at our top-level
    # window for this area (for a move, it'll typically be up to two rectangles)
    my $rs = Tickit::RectSet->new;
    $rs->add($old);
    $rs->add($new);

    # We have moved. This means we may be able to scroll. However! It's not quite that
    # simple. Our move event may cause other panels to move as well, and a move is
    # likely to involve frame redraw as well. See Tickit::Widgget::ScrollBox for more
    # details on the scroll_with_children method.
    if(0 && ($old->left != $new->left || $old->top != $new->top)) {
        my @opt = (
            -($new->top - $old->top),
            -($new->left - $old->left),
        );
        Tickit::Debug->log("Wx", "scrollrect: %s => %s", $float->scroll_with_children(
            @opt
        ), join(',',@opt));
    }

    # Trigger expose events for the area we used to be in, and the new location.
    $win->expose($_) for $rs->rects;

    # Now stash the current extents for this child window so we know what's changed next time.
    $self->{extents}{refaddr $float} = $w->window->rect->translate(0,0);

    # Also pass on the event, so the child widget knows what's going on
    $w->reshape(@_);
}

=head1 API METHODS

These methods are provided as an API for the L<Tickit::Widget::Layout::Desktop::Window> children.
They allow widgets to interact with the desktop for requesting focus etc.

=head2 make_active

Makes the requested L<Tickit::Widget::Layout::Desktop::Window> active - brings it to the front of
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

=head2 weld

"Welds" edges of windows together.

Takes 4 parameters:

=over 4

=item * Source widget edge

=item * Source widget

=item * Destination edge

=item * Destination widget

=back

For example:

 $desktop->weld(
  right => $left_panel,
  left  => $right_panel,
 );

Given a two-panel layout, this would mean any changes to the right edge of the panel on the
left would adjust the left edge of the panel on the right, and vice versa.

As you increase the size of the left panel, the right panel shrinks, so instead of the normal
behaviour where the widget on the left would start to overlap the one on the right, this maintains
the relative positioning by resizing the target widget. This can be used to provide movable dividers
between desktop panels, allowing temporary resize without disrupting the layout.

Returns C< $self > for chaining.

=cut

sub weld {
    my ($self, $src_edge, $src_widget, $dst_edge, $dst_widget) = @_;
    my ($src) = grep { refaddr($src_widget) == refaddr($_->child) } @{$self->{widgets}}
        or die "src not found";
    my ($dst) = grep { refaddr($dst_widget) == refaddr($_->child) } @{$self->{widgets}}
        or die "dst not found";
    push @{$src->{linked_widgets}{$src_edge}}, $dst_edge => $dst;
    push @{$dst->{linked_widgets}{$dst_edge}}, $src_edge => $src;
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

# This will probably end up using Layout::Relative.
#   my %buckets = map { $_ => [] } @directions;
#   foreach my $w (@{$self->{widgets}}) {
#       push @{$buckets{$_}}, { base => $w->window->$_, expand => 1 } for @directions;
#   }
#
#   # Now recalculate the distribution
#   distribute($win->lines, @{$buckets{top}});
#   distribute($win->lines, @{$buckets{lines}});
#   distribute($win->cols, @{$buckets{left}});
#   distribute($win->cols, @{$buckets{cols}});
#   use Data::Dumper;
#   warn Dumper(\%buckets);
#
#   # Then we apply the new sizes back to the widgets
#   foreach my $w (@{$self->{widgets}}) {
#       $w->window->change_geometry(
#           map { (shift @{$buckets{$_}})->{value} } @directions,
#       )
#   }
}

=head2 cascade

Arrange all the windows in a cascade (first at 1,1, second at 2,2, etc.).

=cut

sub cascade {
    my $self = shift;
    my @windows = reverse $self->window->subwindows;
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

=head2 close_all

Close all the windows.

=cut

sub close_all {
    my $self = shift;
    $_->close for reverse $self->window->subwindows;
}

sub close_panel {
    my ($self, $panel) = @_;
    my $rect = $panel->window->rect;
    my $addr = refaddr($panel);
    List::UtilsBy::extract_by { refaddr($_) == $addr }@{ $self->{widgets} };
    $panel->window->close;
    my $win = $self->window;
    $win->tickit->later(sub {
        $win->expose($rect);
    })
}

# Tickit::Widget
sub focus_next {
    my ($self) = shift;
    $self->SUPER::focus_next(@_)
}

1;

__END__

=head1 SEE ALSO

=over 4

=item * L<Tickit::Widget::FloatBox> - eventually ::Desktop will probably start using FloatBox for the float management

=back

=head1 AUTHOR

Tom Molesworth <TEAM@cpan.org>

=head1 LICENSE

Copyright Tom Molesworth 2011-2020. Licensed under the same terms as Perl itself.

