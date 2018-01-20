#!/bin/perl

die "usage: perl splitTreeFileRsp {[-f #] | [-mb #]} rspFile.rsp\n" if (@ARGV != 3);

# save the RSP name
$rsp = pop;


$arg = shift;
if ($arg eq "-f")
{
	# total the size of all the files in the RSP
	open(RSP, $rsp);
	while (<RSP>)
	{
		chomp;
		s/.*@ +//;
		$size = -s; # || die "-s failed on $_";;
		$totalSize += $size;
		#print $totalSize, " ", $size, " ", $_, "\n";
	}
	close(RSP);

	# calculate file size
	$files = shift;
	$split = ($totalSize / $files) / (1024 * 1024);
	print "spliting into $files of approximately $split mb\n";
}
elsif ($arg eq "-mb")
{
	$files = 0;
	$split = shift(@ARGV);
	print "spliting into $split mb sized files\n";
}
else
{
	die "unknown split.  run with no arguments for help\n";
}

# split
$out = $rsp;
$out =~ s/\.rsp$//;
$split *= 1024 * 1024;
$totalSize = 0;
$file = 1;
open(OUTPUT, ">" . $out . "_" . sprintf("%02d", $file) . ".rsp");
print $out, "_", sprintf("%02d", $file), ".rsp";
open(RSP, $rsp);
while (<RSP>)
{
	$save = $_;
	
	chomp;
	s/.*@ +//;
	$size = -s; # || die "-s failed on $_";;
	
	# start a new file if this one is too big
	if (($files == 0 || $file != $files) && $totalSize + $size > $split)
	{
		print "  ", $totalSize, "\n";
		close(OUTPUT);
		$file += 1;
		open(OUTPUT, ">" .$out . "_" . sprintf("%02d", $file) . ".rsp");
		print $out, "_", sprintf("%02d", $file), ".rsp";
		$totalSize = 0;
	}

	$totalSize += $size;
	print OUTPUT $save;
}
print "  ", $totalSize, "\n";
close(OUTPUT);
close(RSP);
