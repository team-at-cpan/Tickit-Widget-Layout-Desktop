package Tickit::Demo;
use strict;
use warnings;
use Module::Pluggable require => 1, instantiate => 'new';

sub new { my $class = shift; bless { @_ }, $class }

sub tickit { shift->{tickit} }
sub desktop { shift->{desktop} }
sub loop { shift->{loop} }

1;
