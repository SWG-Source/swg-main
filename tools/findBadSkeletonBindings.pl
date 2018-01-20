#!/bin/perl
use strict;

use Iff;

my %filenamesToProcess;
my $debug = 0;
my %skeletonNames;

sub collectFileNamesToProcess
{
	foreach my $filenameGlob (@_)
	{
		my @filenames = glob($filenameGlob);
		foreach my $filename (@filenames)
		{
			$filenamesToProcess{$filename} = 1;
		}
	}
}

sub printFileNames
{
	print "Filenames:\n";
	my @sortedFileNames = sort {$a cmp $b} keys %filenamesToProcess;
	foreach my $filename (@sortedFileNames)
	{
		print "$filename\n";
	}

	print "Total: ", scalar(@sortedFileNames), " files\n";
}

sub iffCallbackCollectSkeletons
{
	my $iff = shift;
	my $blockname = shift;
	my $isChunk = shift;

	if ($isChunk && ($blockname eq "SKTI"))
	{
		while ($iff->getChunkLengthLeft() > 0)
		{
			my $skeletonTemplateName = $iff->read_string();
			my $attachmentTransformName = $iff->read_string();
			
			# @todo: catch multiple counts of the same skeleton template name.
			$skeletonNames{$skeletonTemplateName} = 1;
		}
	}

	return 1;
}

sub processSatIff
{
	# Setup args.
	my $satFileName = shift;
	my $iff = shift;
	
	# Collect skeleton templates referenced by this iff.
	%skeletonNames = ();
	$iff->walkIff(\&iffCallbackCollectSkeletons);

	# Process skeleton template names.
	my $faceSkeletonCount = 0;

	foreach my $skeletonTemplateName (sort {$a cmp $b} keys %skeletonNames)
	{
		my $workingSkeletonName = $skeletonTemplateName;

		# Strip off directories in the skeleton template name.
		$workingSkeletonName =~ s!\\!/!;
		$workingSkeletonName =~ s!^.+/!!;

		# Strip off .skt part.
		$workingSkeletonName =~ s!.skt$!!;
		print "workingSkeletonName=[$workingSkeletonName]\n" if $debug;
		
		if ($workingSkeletonName eq "all_b")
		{
			#ignore all_b skeleton.
		}
		elsif ($workingSkeletonName =~ m/([^_]+)_([^_]+)_face/)
		{
			++$faceSkeletonCount;

			my $speciesAbbrev = $1;
			my $genderAbbrev = $2;

			my $invalidSatName = 0;

			my $shouldContainForSpecies = '(^|_)' . $speciesAbbrev . '_';
			if (!($satFileName =~ m/$shouldContainForSpecies/))
			{
				++$invalidSatName;
			}
			
			my $satShouldContainForGender = '_' . $genderAbbrev . '(_|.sat)';
			if (!($satFileName =~ m/$satShouldContainForGender/))
			{
				++$invalidSatName;
			}

			if ($invalidSatName > 0)
			{
				# The SAT file references species/gender specific skeleton template but the SAT filename doesn't indicate the species/gender dependency.\n";
				print "$satFileName\t$skeletonTemplateName\tspecies/gender skeleton referenced, invalid SAT name.\n";
			}
		}
		else
		{
			# Try matching the whole working skeleton name within the sat, indicating that the skeleton and sat are joined.
			my $validSatNamePattern = '(^|_)' . $workingSkeletonName . '(_|.sat)';
			if (!($satFileName =~ m/$validSatNamePattern/))
			{
				print "$satFileName\t$skeletonTemplateName\tunexpected skeleton template name\n";
			}
		}
	}

	print "$satFileName\t****\treferenced $faceSkeletonCount face skeletons\n" if $faceSkeletonCount > 1;
}

sub processFiles
{
	foreach my $filename (@_)
	{
		# Open the file, create an Iff instance from it.
		my $fileHandle;
		open($fileHandle, "<$filename") or die "cannot open file [$filename]: $!";

		my $iff = Iff->createFromFileHandle($fileHandle);

		close($fileHandle);

		# Handle Iff contents.
		my $initialName = $iff->getCurrentName();
		if (($initialName ne "SMAT") || !$iff->isCurrentForm())
		{
			print "$filename: not a .SAT file, ignoring\n";
		}
		else
		{
			$iff->enterForm();
			processSatIff($filename, $iff);
			$iff->exitForm();
		}

	}
}

# Print usage.
die "Usage: perl findBadSkeletonBindings.pl <.sat fileglob> [ <.sat fileglob> [...]]\n" if (@ARGV == 0);

# Collect files to process.
collectFileNamesToProcess(@ARGV);
printFileNames() if $debug;
processFiles(sort {$a cmp $b} keys %filenamesToProcess);
