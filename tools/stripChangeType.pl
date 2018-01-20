#!/bin/perl

while (<>)
{
	if (s/ - \S+ \S+ \d+ \(\S+\)$// == 0)
	{
		die "bad string: " . $_;
	}

	print;
}
