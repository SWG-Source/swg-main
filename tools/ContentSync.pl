#! /usr/bin/perl
#
# Fix for Malformed UTF-8 Character error in perl 5.8.0 on linux - "export LANG=en_US"

use warnings;
use strict;

# ======================================================================
# initialization

# setup perforce access environment variables
my $p4 = "p4";

my $branch = "";
my $startingChangelist = 0;
my $endingChangelist;
my $contentLevel = 2;

my $name = $0;
$name =~ s/^(.*)\\//;

my $logfile = $name;
$logfile =~ s/\.pl$/\.log/;

my $programmer	= 0;
my $designer	= 1;
my $artist	= 2;
my $default	= $programmer;
my %content;

# ======================================================================

sub usage
{
	print STDERR "\nUsage:\n";
	print STDERR "\t$name <branch> <starting changelist> <ending changelist>\n";
	print STDERR "\n\tending changelist can be a changelist or #head\n";
	die "\n";
}

sub getUsers
{
	my ($group, $value) = @_;
	my $foundUsers = 0;
	
	open(P4, "$p4 group -o $group |");
	while(<P4>)
	{
		$foundUsers = 1 if(/^Users:/);
		next if(!$foundUsers);
		$content{$1} = $value if(/^\s+(\S+)/);
	}	
	close(P4);
}

# ======================================================================

&usage() if(@ARGV == 0);

my $forceContentLevel;
if(@ARGV == 4)
{
	$forceContentLevel = shift @ARGV;
}

&usage() if(@ARGV != 3);

$branch = shift;
$startingChangelist = shift;
$endingChangelist = shift;

my $user;

print "Gathering list of users...\n";
getUsers("swg_programmers", $programmer);
getUsers("swg_leads", $programmer);
getUsers("swg_qa", $programmer);
getUsers("swg_designers", $designer);
getUsers("swg_artists", $artist);

if (defined $forceContentLevel) 
{ 
	$contentLevel = $forceContentLevel;
	$user = "ContentLevelOverride";
}
else 
{
	open(P4, "$p4 user -o |") || die "p4 user failed\n";
	while(<P4>)
	{
		if(/^User:\s+(\S+)/)
		{
			$user = $1;
			die "Could not determine if $user is a programmer, designer, or artist\n" if(!exists $content{$user});

			$contentLevel = $content{$user};
		}
	}
	close(P4);
}

my $level;
die "Unknown contentLevel: $contentLevel\n" if($contentLevel < 0);
$level = "programmer" if($contentLevel == 0);
$level = "designer" if($contentLevel == 1);
$level = "artist" if($contentLevel == 2);
$level = "specified content only" if($contentLevel >= 3);

print STDERR "Syncing for $user at content level of $level\n";

print STDERR "Getting changes from $startingChangelist to $endingChangelist...\n";
my @changes;
open(P4, "$p4 changes -s submitted //depot/swg/$branch/...\@$startingChangelist,$endingChangelist |") || die "p4 changes failed\n";
while (<P4>)
{
	chomp;
	s/^Change //;
	s/ .*//;
	unshift @changes, $_;	
}
close(P4);

print STDERR "Scanning changes...\n";
# process all the changelists looking for content files
my %sync;
foreach my $changeList (@changes)
{
	# read the change description
	my $content = 0;
	my $user;
	my $notes = "";
	my $file;
	open(P4, "$p4 -ztag describe -s $changeList |") || die "die: p4 change failed";

		while (<P4>)
		{
			# make the initial decision based on the user
			if (/^\.\.\.\s+user\s+(.*)/)
			{
				$user = $1;
				if (!defined $content{$user})
				{
					# If we don't have the user listed, use default
					$content = $default >= $contentLevel ? 1 : 0;
					print STDERR "could not determine content status of $1 for changelist $changeList\n";
				}
				else
				{
					$content = $content{$user} >= $contentLevel ? 1 : 0;
				}
			}
		
			# allow overrides in the descriptions
			if (/\[\s*no\s+content\s*\]/i)
			{
				$content = 0;
				$notes = " specified [no content]";
			}
			if (/\[\s*content\s*\]/i)
			{
				$content = 1;
				$notes = " specified [content]";
			}

			# remember content files			
			if ($content)
			{
				$file = $1 if (/^\.\.\.\s+depotFile\d+\s+(.*)/);
				$sync{$file} = $1 if (/^\.\.\.\s+rev\d+\s+(.*)/);
	 		}
		}

		# give summary of this changelist
		print "no " if (!$content);
		print "content $changeList $user$notes\n";

	close(P4);
}

if (scalar(keys %sync) != 0)
{
	print STDERR "\nUpdating the client with ", scalar(keys %sync), " file(s)...\n";
	open(P4, "| $p4 -x - sync > $logfile 2>&1");
		foreach (sort keys %sync)
		{
			print P4 $_, "#", $sync{$_}, "\n";
		}
	close(P4);
}
else
{
	print STDERR "No files to update.\n";
}

#unlink($logfile);
