#! /usr/bin/perl

use warnings;
use strict;
use Socket;

die "usage: $0 [max_changelist]\n\tProcess change lists and automatically push appropriate ones to the stage label\n" if (@ARGV > 1 || !($ARGV[0] =~ /^\d+$/));

# ======================================================================
# set up global constants

my $counter         = "swg-stage-counter";
my $label           = "swg-stage-label";
my $group           = "swg_stage_group";

# ======================================================================

my $maxChangeList = shift;
if (!defined $maxChangeList)
{
	open(P4, "p4 counter change |") || die "$0: p4 review failed";
		$maxChangeList = <P4>;
		chomp $maxChangeList;
	close(P4);
}

# get the list of changelists to review	
open(P4, "p4 review -t $counter |") || die "$0: p4 review failed";
	my @review = <P4>;
close(P4);

# bail out fast if there are no new change lists
if (@review == 0)
{
	print STDERR "No new changelists, done.\n";
	exit(0);
}

# get the stage group membership from perforce
my %stageUsers;
open(P4, "p4 group -o $group |") || die "$0: p4 group failed";
	while (<P4>)
	{
		last if (/^Users:/);
	}
	while (<P4>)
	{
		chomp;
		s/\s+//g;
		$stageUsers{$_} = 1;
	}
close(P4);

# process all change lists
my %sync;
my $changeList;
while (@review)
{
	# process this submitted change list
	$_ = shift @review;
	chomp;
	my $user;
	{
		my $junk;
		my $rest;
		($junk, $changeList, $user, $rest) = split;
	}

	# keep to out max changelist
	last if ($changeList > $maxChangeList);

	# read the change description
	open(P4, "p4 -ztag describe -s $changeList |") || die "$0: p4 change failed";
		my @describe = <P4>;
		chomp @describe;
	close(P4);

	# check if this change list should go to stage
	my $update = defined($stageUsers{$user}) ? 1 : 0;
	$update = 1 if (grep /\[stage\]/i, @describe);
	$update = 0 if (grep /\[no[ _]*stage\]/i, @describe);

	if ($update)
	{
		my $update = 0;
		my $file;
		foreach (@describe)
		{
			$file = $_ if (s/^\.\.\.\s+depotFile\d+\s+// && (m%^//depot/swg/current/data/% || m%^//depot/swg/current/dsrc/%));
			if (defined $file && s/^\.\.\.\s+rev\d+\s+//)
			{
				$update += 1;
				$sync{$file} = $_;
				undef $file;
			}
		}

		print STDERR "\t$changeList [stage] $user ($update files)\n";
	}
	else
	{
		print STDERR "\t$changeList [no stage] $user\n";
	}
}

# see if we need to update any files
my $sync = scalar keys %sync;
if ($sync != 0)
{
	# figure out my perforce user name
	my $userName;
	open(P4, "p4 info |");
		while (<P4>)
		{
			chomp;
			$userName = $_ if (s/User name: //);
		}
	close(P4);

	# check who owns the label
	my $isOwner = 1;
	my @label;
	open(P4, "p4 label -o $label |");
		while (<P4>)
		{
			chomp;
			if (/^Owner:\t/ && $_ ne "Owner:\t$userName")
			{
				$_ = "Owner:\t$userName";
				$isOwner = 0;
			}
			push(@label, $_);
		}
	close(P4);

	# make me the owner of the label if I wasn't already	
	if (!$isOwner)
	{
		open(P4, "| p4 label -i > nul");
			foreach (@label)
			{
				print P4 $_, "\n";
			}
		close(P4);
	}

	my $start = time;
	print STDERR "Updating the label... (", $sync, " files)\n";
	open(P4, "| p4 -x - labelsync -l $label > nul") || die "$0: labelsync failed\n";
		foreach (sort keys %sync)
		{
			print P4 $_, "#", $sync{$_}, "\n";
		}
	close(P4);
	my $elapsed = time - $start;
	print STDERR "Update took ", $elapsed, " seconds\n";
}

# update the counter to the last processed change list
system("p4 counter $counter $changeList > nul") == 0 || die "$0: counter update failed\n";

print STDERR "Stage label update complete to changelist $changeList.\n";
