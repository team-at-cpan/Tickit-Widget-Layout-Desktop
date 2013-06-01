#!/usr/bin/env perl 
use strict;
use warnings;
use Tickit::DSL;

vbox {
  my $label = static 'text';
  entry { $label->set_text($_[1]) };
};
tickit->run;
