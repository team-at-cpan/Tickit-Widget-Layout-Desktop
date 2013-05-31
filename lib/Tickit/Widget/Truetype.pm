package Tickit::Widget::Truetype;
use strict;
use warnings;
use parent qw(Tickit::Widget);

use Tickit::Render::Truetype;

sub lines { 1 }
sub cols { 1 }

sub new {
	my $class = shift;
	my %args = @_;
	my $txt = delete $args{text};
	my $font = delete $args{font};
	my $self = $class->SUPER::new(%args);
	$self->{text} = $txt // '';
	$self->{font} = $font;
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
	$ttf->render_text(
		$rc,
		text => $self->text,
		pen => $self->pen,
		size => 24,
	);
	$rc->flush_to_window($win);
}

sub text { shift->{text} // '' }
sub font { shift->{font} }

sub set_text {
	my $self = shift;
	$self->{text} = shift // '';
	$self->redraw;
}

1;
