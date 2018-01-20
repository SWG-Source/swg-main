#!/usr/bin/perl

use warnings;
use strict;

sub numerically
{
	$a <=> $b;
}

# check command line arguments
if (@ARGV < 2 || ($ARGV[0] =~ /^[-\/]/) ||  !($ARGV[0] =~ /tre$/i))
{
	die "usage: $0 [treefile.tre] [changelist ...]\n";
}

my $tre = shift;

# process all changelists gathering up files for the TRE
print "Processing changelists\n";
my %file;
foreach my $changelist (sort numerically @ARGV)
{
	print "\t$changelist\n";
	open(P4, "p4 describe -s $changelist |");
	while (<P4>)
	{
		chomp;
		if (s%^\.\.\. //depot/swg/live/(data/sku.\d+/sys.(client|shared)/[^\/]+/[^\/]+)/%%)
		{
			my $prefix = $1;
			s/#\d+ .*//;
			$file{$_} = "../../$prefix/" . $_;
			
		}
	}
	close(P4);
}
print"\n";

# generate the tree file response file
print "Generating response file\n";
my $rsp = $tre;
$rsp =~ s/tre$/rsp/i;
open(RSP, ">" . $rsp);
foreach (sort keys %file)
{
	print "\t", $_, " @ ", $file{$_}, "\n";
	print RSP $_, " @ ", $file{$_}, "\n";
}
close(RSP);
print"\n";

# build the tree file
print "Generating tree file\n";
open(TRE, "TreeFileBuilder -r $rsp $tre |");
print "\t", $_ while (<TRE>);
close(TRE);
print "\n";

# generate the md5sum for the file
print "Generating md5sum\n";
my $md5 = $tre;
$md5 =~ s/tre$/md5/i;
system("md5sum -b $tre > $md5");
open(MD5, $md5);
print "\t", $_ while (<MD5>);
close(MD5);
