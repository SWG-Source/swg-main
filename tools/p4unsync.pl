#!/usr/bin/perl

$sync = "sync";

while ($ARGV[0] =~ /^-/)
{
	$arg = shift;
	$sync = "flush" if ($arg eq "-f");
	$revert = 1     if ($arg eq "-r");
}

die "Cannot specify both flush and revert" if ($sync eq "flush" && $revert);

# scan the changelists remembering the highest and lowest revision numbers for each file
while (defined($change = shift))
{
	open(FILE, "p4 describe -s " . $change . " |");
	while (<FILE>)
	{
		if (/^\.\.\./)
		{
			chomp;
			s/^\.\.\. //;
			$delete = 0;
			$delete = 1 if (/#\d+ delete/);
			($file, $version) = split /#/;
			$version =~ s/ .*//;
			$min{$file} = $version if (!defined($min{$file}) || $version < $min{$file});
			if (!defined($max{$file}) || $version > $max{$file})
			{
				$max{$file} = $version;
				$deleted{$file} = $delete;
			}
		}
	}
	close(FILE);
}

# make sure we saw some files
die "no changelists specified." if (%min == 0);

# sync to the revision before any revision in these files
open(P4, "| p4 -x - " . $sync);
foreach $file (sort keys %min)
{
	print P4 $file . "#" . ($min{$file} - 1) . "\n";
}
close(P4);

if ($revert)
{
	foreach $file (sort keys %max)
	{
		die "unknown $file" if (!defined $deleted{$file});
		if ($min{$file} == 1)
		{
			push (@added, $file)
		}
		elsif ($deleted{$file})
		{
			push (@deleted, $file);
		}
		else
		{
			push (@changed, $file);
		}
	}

	@added = sort @added;
	@changed = sort @changed;
	@deleted = sort @deleted;

	if (@changed)
	{
		# open the files for edit at that revision
		open(P4, "| p4 -x - edit");
		foreach $file (@changed)
		{
			print P4 $file, "\n";
		}
		close(P4);

		# sync to the maximum version in all the changelists
		open(P4, "| p4 -x - sync");
		foreach $file (@changed)
		{
			print P4 $file, "#", $max{$file}, "\n";
		}
		close(P4);

		# resolve the conflict by accepting the copy of the file we have
		open(P4, "| p4 -x - resolve -ay");
		foreach $file (@changed)
		{
			print P4 $file, "\n";
		}
		close(P4);
	}
	
	if (@deleted)
	{
		# open the files for edit at that revision
		open(P4, "| p4 -x - flush");
		foreach $file (@deleted)
		{
			print P4 $file, "#0\n";
		}
		close(P4);

		open(P4, "| p4 -x - add");
		foreach $file (@deleted)
		{
			print P4 $file, "\n";
		}
		close(P4);
	}

	if (@added)
	{
		open(P4, "| p4 -x - flush");
		foreach $file (@added)
		{
			print P4 $file, "\n";
		}
		close(P4);

		open(P4, "| p4 -x - delete");
		foreach $file (@added)
		{
			print P4 $file, "\n";
		}
		close(P4);
	}
}
