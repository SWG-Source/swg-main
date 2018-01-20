#!/usr/bin/perl

use strict;
use warnings;

my $debug = 100;

sub numerically()
{
	return $a <=> $b;
}

die "usage: $0\n\tDetermines what changelists need to be pushed to test\n" if (@ARGV != 0);

my $p4 = "p4";

# read in the data files list
print STDERR "reading current files" if ($debug);
my %data_revisions;
open(P4, "$p4 -ztag files //depot/swg/current/data/... //depot/swg/current/dsrc/... |");
while (!eof(P4))
{
	my $depotFile;
	my $revision;
	
	while (<P4>)
	{
		chomp;
		if ($_ eq "")
		{
			last;
		}
		elsif (s/^\.\.\. depotFile //)
		{
			$depotFile = $_;
		}
		elsif (s/^\.\.\. rev //)
		{
			$revision = $_;
		}
	}
	
	die "missing depotFile" if (!defined($depotFile));
	die "missing revision " if (!defined($revision));
	$data_revisions{$depotFile} = $revision;
}
close(P4);
my @data_keys = sort keys %data_revisions;
print STDERR " (", scalar(@data_keys), " files)\n" if ($debug);

# read in the stage files list
print STDERR "reading stage files" if ($debug);
my %stage_revisions;
open(P4, "$p4 -ztag files //depot/swg/current/data/...\@swg-stage-label //depot/swg/current/dsrc/...\@swg-stage-label |");
while (!eof(P4))
{
	my $depotFile;
	my $revision;
	
	while (<P4>)
	{
		chomp;
		if ($_ eq "")
		{
			last;
		}
		elsif (s/^\.\.\. depotFile //)
		{
			$depotFile = $_;
		}
		elsif (s/^\.\.\. rev //)
		{
			$revision = $_;
		}
	}
	
	die "missing depotFile" if (!defined($depotFile));
	die "missing revision " if (!defined($revision));
	$stage_revisions{$depotFile} = $revision;
}
close(P4);
my @stage_keys = sort keys %stage_revisions;
print STDERR " (", scalar(@stage_keys), " files)\n" if ($debug);

print STDERR "comparing current vs stage" if ($debug);
# compare the two sets of files
my @new_revisions;
my $changed = 0;
while (@data_keys)
{
	if (@stage_keys && ($data_keys[0] eq $stage_keys[0]))
	{
		my $key = shift @data_keys;
		my $s = shift @stage_keys;
		if ($data_revisions{$key} != $stage_revisions{$key})
		{
			$changed += 1;
			foreach my $revision ($stage_revisions{$key}+1 .. $data_revisions{$key})
			{
				push(@new_revisions, "$key#$revision");
			}
		}
	}
	else
	{
		die "\nD\n$data_keys[0]\n$stage_keys[0]\n" if (@stage_keys && $stage_keys[0] lt $data_keys[0]);

		$changed += 1;

		my $key = shift @data_keys;
		foreach my $revision (1 .. $data_revisions{$key})
		{
			push(@new_revisions, "$key#$revision");
		}
	}
}
print STDERR " (", $changed, " files changed)\n" if ($debug);

# generate the temp file of the revisions
print STDERR "finding changelists" if ($debug);
my $fstat = "fstat.tmp";
open(FSTAT, ">" . $fstat);
foreach (@new_revisions)
{
	print FSTAT $_, "\n";
}
close(FSTAT);
my %changes;
my @labelsync;
open(P4, "$p4 -x $fstat fstat |") || die "$0: Could not open p4 fstat pipe: $!\n";
	while (<P4>)
	{
		chomp;
		if (s/^\.\.\. headChange //)
		{
			# print $_, "\t", (shift @new_revisions), "\n";
			$changes{$_} = 1;
		}
	}
close(P4);
unlink($fstat);
print STDERR " (", scalar keys %changes, " changes)\n" if ($debug);

# get a description of each changelist
print STDERR "getting changelist descriptions\n" if ($debug);
foreach (sort numerically keys %changes)
{
	open(P4, "$p4 describe -s $_|");
		my $header = <P4>;
		while (<P4>)
		{
			$header = "" if (/\[automated\]/);
		}
	close(P4);
	print $header;
}
