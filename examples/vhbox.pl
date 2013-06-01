#!/usr/bin/env perl 
use strict;
use warnings;
use Tickit::DSL;

vbox {
  widget {
    hbox {
      widget { static 'top left', align => 'left' } expand => 1;
      widget { static 'top middle', align => 'centre' } expand => 1;
      widget { static 'top right', align => 'right' } expand => 1;
    }
  } expand => 1;
  widget {
    hbox {
      widget { static 'middle left', align => 'left', valign => 'middle' } expand => 1;
      widget { static 'middle', align => 'centre', valign => 'middle' } expand => 1;
      widget { static 'middle right', align => 'right', valign => 'middle' } expand => 1;
    }
  } expand => 1;
  widget {
    hbox {
      widget { static 'bottom left', align => 'left', valign => 'bottom' } expand => 1;
      widget { static 'bottom', align => 'centre', valign => 'bottom' } expand => 1;
      widget { static 'bottom right', align => 'right', valign => 'bottom' } expand => 1;
    }
  } expand => 1;
};
tickit->run;
