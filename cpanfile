requires 'parent', 0;
requires 'Tickit', '>= 0.46';
requires 'Tickit::Widget', 0;
requires 'Tickit::WidgetRole::Movable', '>= 0.002';
requires 'curry::weak', 0;

on 'test' => sub {
	requires 'Test::More', '>= 0.98';
};
