package Tickit::Widget::Palette;
use strict;
use warnings;
use parent qw(Tickit::Widget);

use constant CLEAR_BEFORE_RENDER => 0;

use Tickit::Render::Truetype;
use List::Util qw(sum max);
use POSIX qw(floor);

my @TEXT = <DATA>;

sub lines { 1 }
sub cols { 1 }

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

	my $row = 0;
	$rc->goto($row, 0);
	$rc->text("Based on http://excess.org/urwid/browser/examples/palette_test.py", $self->pen);
	++$row;
	for (@TEXT) {
		chomp(my $line = $_);
		$rc->goto($row, 0);
		MATCH:
		while(length $line) {
			my $found = 0;
			while($line =~ s/^ //) {
				$rc->text(" ", $self->pen);
				++$found;
			}
			while($line =~ s/^#([[:xdigit:]]{3})(_*)//) {
				my $colour = $self->colour(map hex($_) / 15, split //, $1);
				$rc->text('#' . $1 . (' ' x length($2)), Tickit::Pen->new(fg => $colour));
				++$found;
			}
			while($line =~ s/^(g(\d+)_*)//) {
				$rc->text($1, Tickit::Pen->new(fg => $self->colour(map $2 / 100, 1..3)));
				++$found;
			}
			while($line =~ s/^(\w+)(_*)//) {
				$rc->text($1 . (' ' x length($2)), Tickit::Pen->new(fg => $1));
				++$found;
			}
#last MATCH unless $found;
			substr $line, 0, 1, '' unless $found;
		}
		++$row;
	}
	$rc->flush_to_window($win);
}

sub _zero_offset { 16 }
sub _green_offset { 6 }
sub _red_offset { 36 }
sub _blue_offset { 1 }
sub _green_max { 5 }
sub _red_max { 4 }
sub _blue_max { 5 }

my %base16 = (
	'800' => 1,
	'080' => 2,
	'880' => 3,
	'008' => 4,
	'808' => 5,
	'088' => 6,
	'ccc' => 7, # one of these is not like the others...
	'888' => 8,
	'f00' => 9,
	'0f0' => 10,
	'ff0' => 11,
	'00f' => 12,
	'f0f' => 13,
	'0ff' => 14,
	'fff' => 15,
);

sub colour {
	my $self = shift;
	my @max = (4, 5, 5);

	# These should be usable as offsets into the colour cube
	my @scaled = map floor(0.5 + ($_[$_] * $max[$_])), 0..$#_;

	# This is a stepped value taking into account the resolution in the colour cube
	my @ratio = map floor(0.5 + $_[$_] * $max[$_]), 0..$#_;

	# and an 'RGB' version (single digit hex for each component)
	my $as_hex = sprintf '%x%x%x', map floor(0.5 + 15 * $_), @_;

	# If we think it's one of the greys, use the 12-point scale there directly
	return 232 + floor(0.5 + ($_[1] * 12)) if $as_hex =~ /^(.)\1\1/ && $as_hex ne '000' && $as_hex ne '888' && $as_hex ne 'fff';

	# One of the base 16 colours? Have some of that
	return $base16{$as_hex} if exists $base16{$as_hex};

	# Try to guess one from the remaining 216-ish entries in the cube
	return sum $self->_zero_offset, map $self->${\"_${_}_offset"} * shift(@scaled), qw(red green blue);
}

1;

__DATA__

              #00f#06f#08f#0af#0df#0ff
            #60f#00d#06d#08d#0ad#0dd#0fd
          #80f#60d#00a#06a#08a#0aa#0da#0fa
        #a0f#80d#60a#008#068#088#0a8#0d8#0f8
      #d0f#a0d#80d#608#006#066#086#0a6#0d6#0f6
    #f0f#d0d#a0a#808#606#000#060#080#0a0#0d0#0f0#0f6#0f8#0fa#0fd#0ff
      #f0d#d0a#a08#806#600#660#680#6a0#6d0#6f0#6f6#6f8#6fa#6fd#6ff#0df
        #f0a#d08#a06#800#860#880#8a0#8d0#8f0#8f6#8f8#8fa#8fd#8ff#6df#0af
          #f08#d06#a00#a60#a80#aa0#ad0#af0#af6#af8#afa#afd#aff#8df#6af#08f
            #f06#d00#d60#d80#da0#dd0#df0#df6#df8#dfa#dfd#dff#adf#8af#68f#06f
              #f00#f60#f80#fa0#fd0#ff0#ff6#ff8#ffa#ffd#fff#ddf#aaf#88f#66f#00f
                                    #fd0#fd6#fd8#fda#fdd#fdf#daf#a8f#86f#60f
      #66d#68d#6ad#6dd                #fa0#fa6#fa8#faa#fad#faf#d8f#a6f#80f
    #86d#66a#68a#6aa#6da                #f80#f86#f88#f8a#f8d#f8f#d6f#a0f
  #a6d#86a#668#688#6a8#6d8                #f60#f66#f68#f6a#f6d#f6f#d0f
#d6d#a6a#868#666#686#6a6#6d6#6d8#6da#6dd    #f00#f06#f08#f0a#f0d#f0f
  #d6a#a68#866#886#8a6#8d6#8d8#8da#8dd#6ad       
    #d68#a66#a86#aa6#ad6#ad8#ada#add#8ad#68d   
      #d66#d86#da6#dd6#dd8#dda#ddd#aad#88d#66d        g78_g82_g85_g89_g93_g100  
                    #da6#da8#daa#dad#a8d#86d        g52_g58_g62_g66_g70_g74_
      #88a#8aa        #d86#d88#d8a#d8d#a6d        g27_g31_g35_g38_g42_g46_g50_
    #a8a#888#8a8#8aa    #d66#d68#d6a#d6d        g0__g3__g7__g11_g15_g19_g23_
      #a88#aa8#aaa#88a                        
            #a88#a8a

