#!/bin/perl
use strict;

# Call with the following args:
#   -n <newVariableNameFile> -a <assetInfoFile>

my $newVariableFileName;
my $assetInfoFileName;
my $debug = 0;

my %targetVariableNames;

sub loadTargetVariableNamesFromFile
{
	my $filename = shift;
	my $fileHandle;

	open($fileHandle, "<$filename") or die "failed to open file [$filename]: $!";
	
	while (<$fileHandle>)
	{
		chomp;
		if ($_ =~ m/\[(.+)\]/)
		{
			my $name = $1;
			$targetVariableNames{$name} = 1;
			print STDERR "target variable [$name]\n" if $debug;
		}
	}

	close($fileHandle);
}

sub findVariableNameUsage
{
	my $filename = shift;
	my $fileHandle;

	print "variableName\treferencing assetName\n";

	open($fileHandle, "<$filename") or die "failed to open file [$filename]: $!";
	while (<$fileHandle>)
	{
		chomp;
		if (($_ =~ m/^I /) || ($_ =~ m/^P /))
		{
			# kill code letters.
			s/..//;

			# read asset name and variable name.
			m/([^:]+):([^:]+):/ or die "line [$_] does not match customization variable info data format";
			my $assetName = $1;
			my $variableName = $2;

			# if the variable name is one of the targets, print out the asset.
			if (exists $targetVariableNames{$variableName})
			{
				print "$variableName\t$assetName\n";
			}
		}
	}
	close($fileHandle);
}

# Process args
while (@ARGV)
{
	my $currentArg = shift @ARGV;
	if ($currentArg =~ m/-d/)
	{
		$debug = 1;
		print STDERR "debugging turned on\n";
	}
	elsif ($currentArg =~ m/-n/)
	{
		$newVariableFileName = shift @ARGV;
		print STDERR "newVariableFileName=[$newVariableFileName]\n" if $debug;
	}
	elsif ($currentArg =~ m/-a/)
	{
		$assetInfoFileName = shift @ARGV;
		print STDERR "assetInfoFileName=[$assetInfoFileName]\n" if $debug;
	}
}

# Load in new variable names
loadTargetVariableNamesFromFile($newVariableFileName);

# Find asset usage of target names
findVariableNameUsage($assetInfoFileName);
