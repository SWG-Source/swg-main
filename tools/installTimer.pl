#! /usr/bin/perl

use strict;
use warnings;

my $minimumTime = 0.0;

if (@ARGV >= 2 && $ARGV[0] eq "-m")
{
	shift;
	$minimumTime = shift;
}

die "usage: $0 [-m time] logfile\n\t-m = minimum time (in seconds) to report\n" if (@ARGV != 1 || $ARGV[0] =~ /^[-\?\/]/);

my @reverse;
while (<>)
{
	next if (s/InstallTimer:  // == 0);
	push(@reverse, $_);
}

while (@reverse)
{	
	$_ = pop(@reverse);
	my $line = $_;
	chomp;
	s/^\s+//;
	my ($time, $whom) = split(/\s+/, $_);
	print $line if ($time >= $minimumTime);
}
