package Tickit::Demo::Plugin::Tabs;
use strict;
use warnings;
use parent qw(Tickit::Demo::Widget);

use Tickit::Widget::Tabbed;
use Tickit::Widget::Tabbed::Ribbon::IndexCard;
use Tickit::Widget::Static;

sub label { 'Tabs' }

sub widget {
	my $class = shift;
	my $tabbed = Tickit::Widget::Tabbed->new(
	   tab_position => "top",
	   ribbon_class => "Tickit::Widget::Tabbed::Ribbon::IndexCard",
	);

	$tabbed->pen_active->chattrs( { b => 1, u => 1 } );

	my $counter = 1;
	my $add_tab = sub {
		$tabbed->add_tab(
			Tickit::Widget::Static->new( text => "Content for tab $counter" ),
			label => "tab$counter",
		);
		$counter++
	};

	$add_tab->() for 1 .. 3;

#	$tickit->bind_key(
#		'C-a' => $add_tab
#	);
#	$tickit->bind_key(
#		'C-d' => sub {
#			$tabbed->remove_tab( $tabbed->active_tab );
#		},
#	);
	$tabbed;
}

1;
