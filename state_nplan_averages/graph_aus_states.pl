#!/usr/bin/perl -w

# Info: Based on the CGI script but
# Author: Andrew Harvey (http://andrewharvey4.wordpress.com/)
# Date: 18 Feb 2010 
#
# To the extent possible under law, the person who associated CC0
# with this work has waived all copyright and related or neighboring
# rights to this work.
# http://creativecommons.org/publicdomain/zero/1.0/

use strict;
use POSIX;

my $max = ceil (`cat datafiles/*.csv | cut -d, -f2 | sort -n | tail -n 1`);
my $min = floor (`cat datafiles/*.csv | cut -d, -f2 | sort -n | head -n 1`);

foreach my $f (@ARGV) {
	if (!(-e $f)) {
		next;
	}
	
	open F, $f;
	#readline F;
	
	my %fill;
	my %opacity;
	my %text;
	
	while (<F>) {
		my ($state, $val) = split /,/, $_;
		$state = lc $state;
		
		if ((($val-$min)/($max-$min)) > 0.5 ) {
			$fill{$state} = (sprintf "%02x",255*(($val-$min)/($max-$min))).'ff'.(sprintf "%02x",255*(($val-$min)/($max-$min)));
		}else{
			$fill{$state} = '00'.(sprintf "%02x",255*(($val-$min)/($max-$min))).'00';
		}
		#black    green    white
		#000000 - 00ff00 - ffffff
		$opacity{$state} = 0.8; #so you can still read the text is black fill.
		#$fill{$state} = '00ff00';
		#$opacity{$state} = sprintf "%.3f", ($val-$min)/($max-$min);
		$text{$state} = sprintf "%d", $val;
	}
	
	my $stroke_width = 1;
	my $text_size = 20;

	#open the template file
	open SVG, "australian_states_graphic_text_template.svg";
	open SVGOUT, ">$f.svg";

	#replace the placeholder strings with parameter values
	while (<SVG>) {
		foreach my $k (keys %fill) {
		    $_ =~ s/`${k}_fill`/#$fill{$k}/;
		}
		
		foreach my $k (keys %opacity) {
		    $_ =~ s/`${k}_fill_opacity`/$opacity{$k}/;
		}
		$_ =~ s/`template_stroke_width`/$stroke_width/;
		    
		foreach my $k (keys %text) {
		    $_ =~ s/`${k}_text`/$text{$k}/;
		}
		    
		$_ =~ s/`text_size`/${text_size}px/;
		print SVGOUT $_;
	}
	close SVGOUT;
	close SVG;
}


exit;
