#!/usr/bin/perl

$fileName = $ARGV[0];
$searchText = $ARGV[1];
$replaceText = $ARGV[2];

open (SEARCHFILE, $fileName) or die "Could not open $fileName for reading";
$replacements = 0;

while(<SEARCHFILE>)
{
    $matchLine = $_;
    if($matchLine =~ /$searchText/)
    {
	$replaceString = join($replaceText, split(/$searchText/, $matchLine));
	push(@newFile, $replaceString);
	$replacements += 1;
    }
    else
    {
	push(@newFile, $matchLine);
    }
}

close(SEARCHFILE);

open(OUTFILE, ">", $fileName) or die "Could not open $fileName for writing";
foreach $i (@newFile)
{
    print (OUTFILE $i);
}

print "$replacements replacements made in $fileName\n";
