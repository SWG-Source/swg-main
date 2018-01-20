#! /usr/bin/perl

use warnings;
use strict;

die "usage: $0 [pieces] [filename]\n" if (@ARGV != 2);

my $pieces = shift;
my $file = shift;

die "$file does not exist\n" if (-e $file == 0);

my $copyLoopSize = 16 * 1024;
my $copyLoops = ((-s $file) / $copyLoopSize) / $pieces;

# write out all the interim files, excluding the last (since it's the entire file)
foreach my $piece (1 .. $pieces-1)
{
	open(IN, $file);
	binmode(IN);

	my $dir =  "piece" .  $piece;
	mkdir($dir);
	open(OUT, ">" . $dir . "/" . $file);
	binmode(OUT);
	
	foreach (1 .. ($piece * $copyLoops))
	{
		my $buffer;
		read IN, $buffer, $copyLoopSize;
		print OUT $buffer;
	}
	
	close(IN);
	close(OUT);
}

# copy the last piece
{
	open(IN, $file);
	binmode(IN);

	my $dir =  "piece" .  $pieces;
	mkdir($dir);
	open(OUT, ">" . $dir . "/" . $file);
	binmode(OUT);

	while (1)
	{
		my $buffer;
		read IN, $buffer, $copyLoopSize;
		last if (length $buffer == 0);
		print OUT $buffer;
	}

	close(IN);
	close(OUT);
}

system("md5sum -b $file piece*/*");
