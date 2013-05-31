use strict;
use warnings;
package Tickit::Widget::Tabbed::Ribbon::IndexCard;
use parent qw(Tickit::Widget::Tabbed::Ribbon);

package 
	Tickit::Widget::Tabbed::Ribbon::IndexCard::horizontal;
use parent qw(Tickit::Widget::Tabbed::Ribbon::IndexCard);
use Tickit::RenderContext qw(LINE_SINGLE);
use Tickit::Utils qw( textwidth );

sub lines { 2 }
sub cols  { 1 }

sub render {
	my $self = shift;
	my %args = @_;

	my $win = $self->window or return;
	my @tabs = $self->tabs;

	my $rc = Tickit::RenderContext->new(
		lines => $win->lines,
		cols  => $win->cols,
	);
	$rc->clip( $args{rect} );

	my $pen = Tickit::Pen->new(fg => 'grey', bg => 0, b => 0);
	my $active_pen = Tickit::Pen->new(fg => 'hi-green', bg => 'black');
	my $x = 1;
	$rc->erase_at(0, 0, $win->cols, $pen);
	$rc->hline_at(1, 0, $win->cols - 1, LINE_SINGLE, $pen);
	foreach my $tab (@tabs) {
		my $len = textwidth $tab->label;
		$rc->erase_at(1, $x, $len + 4, $pen) if $tab->is_active;
		$rc->hline_at(1, $x - 1, $x, LINE_SINGLE, $pen);
		$rc->hline_at(1, $x + $len + 3, $x + $len + 5, LINE_SINGLE, $pen);
		$rc->hline_at(0, $x, $x + $len + 3, LINE_SINGLE, $pen);
		$rc->vline_at(0, 1, $x, LINE_SINGLE, $pen);
		$rc->vline_at(0, 1, $x + $len + 3, LINE_SINGLE, $pen);
		$rc->text_at(0, $x + 2, $tab->label, $tab->is_active ? $active_pen : $pen);
		$x += $len + 4;
	}
	$rc->render_to_window( $win );
}

sub scroll_to_visible { }

sub on_mouse {
	my $self = shift;
	my ($ev, $button, $line, $col) = @_;
	return unless $ev eq 'press';

	my $x = 1;
	my $idx = 0;
	foreach my $tab ($self->tabs) {
		my $len = textwidth $tab->label;
		if($x <= $col && $x + $len >= $col) {
			$self->{tabbed}->activate_tab($tab);
			return;
		}
		$x += $len + 4;
		++$idx;
	}
}

1;
