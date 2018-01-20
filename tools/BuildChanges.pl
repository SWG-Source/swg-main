#!/usr/bin/perl

use strict;
use warnings;

sub usage
{
	die "usage: $0 [-i] [-t] perforce_file_spec start_changelist end_changelist\n" .
		"\t-i	show internal notes\n" .
		"\t-t	show testplan\n";
}

my $showInternal = 0;
my $showTestplan = 0;

usage() if (@ARGV < 3);
while ($ARGV[0] eq "-i" || $ARGV[0] eq "-t")
{
	$showInternal = 1 if ($ARGV[0] eq "-i");
	$showTestplan = 1 if ($ARGV[0] eq "-t");
	shift;
}

my $spec = shift;
my $first = shift;
my $last = shift;

open(P4, "p4 changes $spec\@$first,$last |");
my @changes = <P4>;
close(P4);

foreach (@changes)
{
	chomp;
	s/'.*//;
	my $changeline = $_;
	s/^Change //;
	s/ .*//;
	my $change = $_;
		
	open(P4, "p4 describe -s $change |");
	my $public = "";
	my $internal = "";
	my $testplan = "";
	my $junk = "";
	my $section = "junk";
	while (<P4>)
	{
		if (s/^\t//)
		{
			if (/\[public\]/)
			{
				$section = "public";
			}
			elsif (/\[internal\]/)
			{
				$section = "internal";
			}
			elsif (/\[testplan\]/)
			{
				$section = "testplan";
			}
			elsif (/\[/)
			{
				$section = "junk";
			}
			elsif ($_ ne "\n")
			{
				$public .= $_ if ($section eq "public");
				$internal .= $_ if ($section eq "internal");
				$testplan .= $_ if ($section eq "testplan");
			}
		}
		else
		{
			$section = "junk";
		}
	}
	close(P4);

	print $changeline,"\n" if ($public ne "" || ($showInternal && $internal ne "") || ($showTestplan && $testplan ne ""));
	print "[public]\n", $public, "\n" if ($public ne "");
	print "[internal]\n", $internal, "\n" if ($showInternal && $internal ne "");
	print "[testplan]\n", $testplan, "\n" if ($showTestplan && $testplan ne "");
	print "\n\n" if ($public ne "" || $internal ne "" || $testplan ne "");
}
