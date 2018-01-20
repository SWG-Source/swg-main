#!/bin/perl

die "usage: p4group username\n" if (@ARGV != 1 || $ARGV[0] =~ /^-[h?]/);

push(@check, $ARGV[0]);
while (@check)
{
	$_ = shift @check;
	open(P4, "p4 groups " . $_ . "|");
	while (<P4>)
	{
		chomp;
		if (!defined $groups{$_})
		{
			push(@check, $_);
			$groups{$_} = 1;
		}
	}
	close(P4);
}

print join("\n", sort keys %groups);
