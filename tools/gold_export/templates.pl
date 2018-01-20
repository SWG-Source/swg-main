#!/usr/bin/perl

#
# this script generates the update radius data file
# required by the export.pl script.
#
# usage: ./templates.pl >templates.dat
#
# note: it may be necessary to modify the $root
# value so that it points to a valid path
#

use strict;

my $root = "/c/work/swg/s5/dsrc/sku.0/sys.server/compiled/game";

chdir $root;

open( FILES, "find object -type f -name '*.tpf' |" ) || die $!;

sub parse
{
	my $file = @_[0];
	my $radius = 0;
		
	local *INPUT;

	if ( open( INPUT, $file ) )
	{
		
		while (<INPUT>)
		{
			s/[\r\n]//;
			if ( /^\@base\s+(.*)/ )
			{
				my $f = $1;
				$f =~ s/\.iff/\.tpf/;
				my $result = parse( $f );
				$radius = $result if $result;
			}
			
			if ( /UR_far.*\s(\d+)/ )
			{
				$radius = $1;
			}
		}
	}
	
	return $radius;
}

while (<FILES>)
{
	chomp;
	print "$_ ";
	my $range = parse $_;
	print "$range\n";
}
