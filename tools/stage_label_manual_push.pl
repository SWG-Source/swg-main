#!/usr/bin/perl

use strict;
use warnings;

sub numerically
{
	return $a <=> $b;
}

sub usage
{
	die
		"usage: $0 [-d] [-n] [-p] [-b changelist] changelist [changelist ...]\n" .
		"\t-n : Do not update the stage label\n" .
		"\t-b : Break when pulling in the specified changelist as a dependency\n" .
		"\t-p : Estimate the patch size\n";
}

my $nul = "nul";
my $label = "swg-stage-label";

usage() if (@ARGV == 0);

# process command line arguments
my $estimatePatchSize = 0;
my $updateStageLabel = 1;
my @break = ();
while (@ARGV && $ARGV[0] =~ /^[-\?]/)
{
	my $arg = shift;
	if ($arg eq "-n")
	{
		$updateStageLabel = 0;
	}
	elsif ($arg eq "-p")
	{
		$estimatePatchSize = 1;
	}
	elsif ($arg eq "-b")
	{
		push @break, shift;
	}
	else
	{
		usage();
	}
}

# read in the current contents of the stage label
my %stage_revisions;
open(P4, "p4 -ztag files //depot/swg/current/data/...\@$label //depot/swg/current/dsrc/...\@$label |");
while (!eof(P4))
{
	my $depotFile;
	my $rev;

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
			$rev= $_;
		}
	}

	die "missing depotFile" if (!defined($depotFile));
	die "missing revision " if (!defined($rev));
	$stage_revisions{$depotFile} = $rev;
}
close(P4);

# process all the desired change lists
my @changeLists = @ARGV;
my %changeLists;
my %update_revision;
my $loop = 0;
while (@changeLists)
{
	# find all the files in the desired change list
	my @additional = ();
	foreach my $change (@changeLists)
	{
	
		# only look each changelist up once
		next if (defined($changeLists{$change}));
		$changeLists{$change} = $loop;

		# get all the data & dsrc files from the changelist
		open(P4, "p4 -ztag describe -s $change |");

			my $depotFile;
			my $rev;
			while (<P4>)
			{
				chomp;

				# remember all data files
				if (s/^\.\.\. depotFile\d+ // && (m%//depot/swg/current/data/% || m%//depot/swg/current/dsrc/%))
				{
					$depotFile = $_;
				}

				# now we know the revision number of the current depot file										
				if (defined($depotFile) && s/^\.\.\. rev\d+ //)
				{
					my $revision = $_;

					# remember that this file needs to be pushed back to the label
					$update_revision{$depotFile} = 1;
					
					# add revision 0 to the stage label if necessary
					$stage_revisions{$depotFile} = 0 if (!defined($stage_revisions{$depotFile}));

					# look for other file revisions that have not yet been included
					foreach my $check ($stage_revisions{$depotFile}+1 .. $revision-1)
					{
						push(@additional, $depotFile . "#" . $check);
					}

					# stage will be advanced to contain this revision
					$stage_revisions{$depotFile} = $revision if ($stage_revisions{$depotFile} < $revision);
				
					# this depot file has been processed
					undef($depotFile);
				}
			}

		close(P4);
	}

	if (@additional)
	{
		my $fstat = "fstat.tmp";
		open(FSTAT, ">" . $fstat);
			foreach (@additional)
			{
				print FSTAT $_, "\n";
			}
		close(FSTAT);

		open(P4, "p4 -x $fstat -ztag fstat |");
			my %dependsOn;
			while (<P4>)
			{
				chomp;
				if (s/^\.\.\. headChange //)
				{
					my $change = $_;
					die "changelist $change pulled in by $additional[0]\n" if (grep($_ == $change, @break));
					$dependsOn{$change} = 1;
					shift @additional;
				}
			}
		close(P4);
		unlink($fstat);

		@changeLists = sort numerically keys %dependsOn;
	}
	else
	{
		@changeLists = ();
	}
	
	$loop += 1;
}

if ($loop > 1)
{
	print "other dependencies:\n";
	foreach (sort numerically keys %changeLists)
	{
		print "\t", $_, "\n" if ($changeLists{$_} > 0);
	}
}

if ($estimatePatchSize)
{
	my $sync = "sync.tmp";
	open(SYNC, ">" . $sync);
		foreach (sort keys %update_revision)
		{
			print SYNC $_, "#", $stage_revisions{$_}, "\n";
		}
	close(SYNC);
	
	system("p4 -x $sync sync > $nul 2> $nul");
	system("perl estimatePatchSize.pl " . join(" ", sort numerically keys %changeLists));
	unlink($sync);
}

if ($updateStageLabel)
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
		open(P4, "| p4 label -i");
			foreach (@label)
			{
				print P4 $_, "\n";
			}
		close(P4);
	}
	
	print "updating stage label (", scalar keys %update_revision, " files)...\n";
	open(P4, "| p4 -x - labelsync -l $label");
		foreach (sort keys %update_revision)
		{
			print P4 $_, "#", $stage_revisions{$_}, "\n";
		}
	close(P4);
}

print "done\n";
