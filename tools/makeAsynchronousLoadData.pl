#!/usr/bin/perl

use strict;
use warnings;

die "usage: perl makeAsynchronousLoadData sourceFile.log outputFile.mif oldFileList.txt\n" if (@ARGV != 3);

# global variables
my @children = ();
my @files = ();
my $counter = 0;
my %files;
my %fileExtensionIndex;
my %extensionOffset;
my %extensionIndex;
my %children;

# command line arguments
my $inFile = shift;
my $outFile = shift;
my $fileList = shift;

sub numerically
{
	return $a <=> $b;
}

sub extensionOffset_numerically
{
	return $extensionOffset{$a} <=> $extensionOffset{$b};
}

sub next_parent
{
	if (@children)
	{
		my $count = @children;
		my $parent = shift(@children);
		$children{$parent} = join("\n      int32 ", "", $count, $parent, @children) . "\n";
		@children = ();
	}
}

# process the old file table to minimize differential patching
open(FILES, $fileList) || die "could not open file $fileList for reading\n";
while (<FILES>)
{
	chomp();
	$files{$_} = $counter;
	$counter += 2 + length($_) + 1;
	push(@files, $_);

	# now check the extension
	my $extension = $_;
	$extension =~ s/^.*\.//;
	my $extensionIndex = $extensionIndex{$extension};
	if (!defined($extensionIndex{$extension}))
	{
		$extensionIndex{$extension} = scalar keys %extensionOffset;
		$extensionOffset{$extension} = $counter - length($extension) - 1;
		$extensionIndex = $extensionIndex{$extension};
	}
	$fileExtensionIndex{$_} = $extensionIndex;
}
close(FILES);

open(FILES, $inFile) || die "could not open file $inFile for reading\n";
{
	my $opening = 0;

	while (<FILES>)
	{
		# 20030711155304:Viewer:reportLog:TF::open(M) d:/work/swg/test/data/sku.0/sys.client/built/game/appearance/path_arrow.msh @ d:/work/swg/test/data/sku.0/sys.client/built/game/appearance/path_arrow.msh, [size=2109]
		s/\d+\:Viewer\:reportLog\://;

		# check if this is an opening line, which separates primary assets
		if (/^opening/)
		{
			next_parent() if ($opening);
			$opening = 1;
		}
		next if (!$opening);
		next if (!/TF::open/);
		chomp;

		# clean up the file name
		s/^.*TF::open\([A-Z]\) //;
		s/ @.*//;
		s#\\#/#g;
		s#//#/#g;
		tr/A-Z/a-z/;
		s#^.*/appearance/#appearance/#;

		# check for it in the file list
		my $index = $files{$_};
		if (!defined($index))
		{
			$files{$_} = $counter;
			$index = $counter;
			$counter += 2 + length($_) + 1;
			push(@files, $_);
		}
		push(@children, $index) if (scalar(grep(/^$index$/, @children)) == 0);

		# now if the extension is known
		my $extension = $_;
		$extension =~ s/^.*\.//;
		my $extensionIndex = $extensionIndex{$extension};
		if (!defined($extensionIndex))
		{
			$extensionIndex{$extension} = scalar keys %extensionOffset;
			$extensionOffset{$extension} = $counter - length($extension) - 1;
			$extensionIndex = $extensionIndex{$extension};
		}

		# remember the extension table index for this file
		$fileExtensionIndex{$_} = $extensionIndex;
	}

	# finish the last primary asset
	next_parent();
}
close(FILES);

# write out the new file table to minimize the diff the next time the async data is updated
open(FILES, ">" . $fileList) || die "could not open file $fileList for writing\n";
foreach (@files)
{
	print FILES $_, "\n";
}
close(FILES);

# write out the mif data
open(OUTPUT, ">$outFile");
select(OUTPUT);

print "form \"ASYN\"\n";
print "{\n";
print "  form \"0001\"\n";
print "  {\n";
print "    chunk \"NAME\"\n";
print "    {\n";

foreach (@files)
{
print "      int8 0\n";
die "no extension for $_\n" if (!defined($fileExtensionIndex{$_}));
print "      int8 $fileExtensionIndex{$_}\n";
print "      cstring \"$_\"\n";
}

print "    }\n";


print "    chunk \"EXTN\"\n";
print "    {\n";
foreach (sort extensionOffset_numerically keys %extensionOffset)
{
print "      int32 $extensionOffset{$_} // $_\n";
}
print "    }\n";

print "    chunk \"LOAD\"\n";
print "    {\n";

foreach (sort numerically keys %children)
{
	print $children{$_};
}

print "    }\n";
print "  }\n";
print "}\n";

select;
close(OUTPUT);

