#! /usr/bin/perl
# ======================================================================
# ======================================================================

use strict;
use warnings;
use File::Copy;

# ======================================================================
# Globals
# ======================================================================

my $oldManifest        = "dailyPatchSizeOld.mft";
my $newManifest        = "dailyPatchSizeNew.mft";
my $tabFile            = "CheckPatchTreeSize.tab";
my $numberOfTabOuts    = 15;
my $p4                 = "p4";

my $branch;
my $changelist;
my $toolsDir;
my %patchTreeSizes;

my $name = $0;
$name =~ s/^(.*)\\//;
my $logfile = $name;
$logfile =~ s/\.pl$/\.log/;

# ======================================================================
# Subroutines
# ======================================================================

sub getP4dir
{
	my $path = $_[0];

	open(P4, "p4 where ${path}... |"); 
	my $perforceDir;
	while(<P4>)
	{
		$perforceDir = $_;
	}
	my @temp = split /\s+/, $perforceDir;
	my $retDir = $temp[2]; 
	close(P4);

	$retDir =~ s/\.\.\.//g;

	return $retDir;
}

sub usage
{
	die "\n\t$name <input manifest> <branch> [<changelist>]\n\n";
}

sub readMft
{
	my ($filename, $hashRef) = @_;

	return if (!-e $filename);

	open(MFT, $filename);

	my $version = <MFT>;
	chomp $version;
	$version =~ s/ .*//;
	die "unsupported manifest version" if ($version ne "version2");

	while(<MFT>)
	{
		my ($archive, $action, $uncsize, $cmpsize, $checksum, $depotfile, $file) = /^(\S+)\t\S+\t(\S+)\t\S+\t(\S+)\t(\S+)\t(\S+)\t(\S+)\#\d+\t(\S+)\n$/;
		next if(!defined $file);
		$$hashRef{$depotfile} = [$checksum, $file, $archive, $action, $uncsize, $cmpsize];
	}
	close(MFT);
}

sub doSync
{
	my $oldchangelist = -1;

	open(TABFILE, $tabFile) || goto NOTABFILE;
	while(<TABFILE>)
	{
		$oldchangelist = $1 if(/(\d+)\n/);
	}
	close(TABFILE);

NOTABFILE:

	if($oldchangelist == -1)
	{  
		system("$p4 sync //depot/swg/$branch/data/...\@$changelist //depot/swg/$branch/exe/win32/...\@$changelist > $logfile 2>&1");
	}
	else 
	{
		system("$p4 sync //depot/swg/$branch/data/...\@$oldchangelist,$changelist //depot/swg/$branch/exe/win32/...\@$changelist > $logfile 2>&1");	
	}
}

sub doExcelOut
{
	my @tabOuts;

	print "\nTab delimeted output for $branch:\n";

	my @skus = (sort keys %patchTreeSizes);
	print "Time\t";
	foreach (@skus)
	{  
		print "sku.$_\t";
	}
	print "Changelist\n";

	if (-e $tabFile)
	{
		open(TABFILE, $tabFile);
		while(<TABFILE>)
		{
			push @tabOuts, $_;
		}
		close(TABFILE);
	}

	while(@tabOuts > $numberOfTabOuts)
	{
		shift @tabOuts;
	}

	foreach (@tabOuts)
	{
		print;
	}

	my ($sec, $min, $hr, $day, $mon, $yr) = localtime time;
	my $timestamp = sprintf "%4s-%02s-%02s %02s:%02s:%02s", ($yr + 1900), ($mon + 1), $day, $hr, $min, $sec;

	my $output = "$timestamp\t";
	foreach (@skus)
	{
		if(exists $patchTreeSizes{$_})
		{
			$output .= "$patchTreeSizes{$_}\t";
		}
		else
		{
			$output .= "0\t";
		}
	}
	$output .= "$changelist\n";

	print $output;
	open(TABFILE, ">>$tabFile");
	print TABFILE $output;
	close(TABFILE);
}

sub doChanges
{
	my %oldMft;
	my %newMft;
	my @output;

	# Read in the mft file information 
	readMft($oldManifest, \%oldMft); 
	readMft($newManifest, \%newMft); 

	# Check for differences
	foreach (keys %newMft)
	{
		# Only update output if the file is new, or the checksum has changed
		next if(exists $oldMft{$_} && $newMft{$_}->[0] eq $oldMft{$_}->[0]);

		my $uncDiff = $newMft{$_}->[4] - ((exists $oldMft{$_}) ? $oldMft{$_}->[4] : 0);
		my $cmpDiff = $newMft{$_}->[5] - ((exists $oldMft{$_}) ? $oldMft{$_}->[5] : 0);
		push @output, join("\t", $_, $newMft{$_}->[1], $newMft{$_}->[2], $newMft{$_}->[3], $uncDiff, $cmpDiff);
	}

	print "\nFiles changed for $branch:\n";
	print join("\t", "Depot Name", "File Name", "Archive", "Action", "Size Added (Uncompressed)", "Size Added (Compressed)"), "\n";
	@output = sort { $a cmp $b } @output;
	print join "\n", @output;
}

# ======================================================================
# Main
# ======================================================================

usage() if(@ARGV < 2);

my $inputManifest = shift;
$branch = shift;

$changelist = `p4 counter change`;
chomp $changelist;
$changelist = shift if (@ARGV);

$toolsDir = getP4dir("//depot/swg/current/tools/");
my $buildClientDataTreeFiles = getP4dir("//depot/swg/all/tools/build/shared/buildClientDataTreeFiles.pl");

my $exeDir = getP4dir("//depot/swg/$branch/exe/win32/");
chdir $exeDir or die "Could not change directory: $!";
my $pwd = `pwd`;
chomp $pwd;
$ENV{"PWD"} = $pwd;

doSync();

system("perl $buildClientDataTreeFiles --noVerify $newManifest $inputManifest 0 > $logfile");

die "Error creating patch tree - patch_0_00.tre does not exist\n" if(!-e "patch_0_00.tre");

opendir DH, $exeDir;
foreach (sort readdir DH)
{
	if(/patch_sku([^_]+)_0_(\d+)\.tre/)
	{
		$patchTreeSizes{$1} = 0 if (!exists $patchTreeSizes{$1});
		$patchTreeSizes{$1} += (-s $_);
	}
	elsif (/patch_0_(\d+)\.tre/)
	{
		$patchTreeSizes{0} = 0 if (!exists $patchTreeSizes{0});
		$patchTreeSizes{0} += (-s $_);
	}
}
closedir DH;

print "Patch tree sizes for $branch:\n";

foreach (sort keys %patchTreeSizes)
{
	print "Size of sku$_.tre is: ".$patchTreeSizes{$_}."\n";
}

doExcelOut();
doChanges() if(-e $oldManifest);

move $newManifest, $oldManifest || die "move from $newManifest to $oldManifest failed";
