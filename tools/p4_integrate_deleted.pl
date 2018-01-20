#!/usr/bin/perl

# handle command line arguments
die "usage: perl p4_integrate_deleted.pl branch-name\n" if (scalar(@ARGV) != 1);

# read in the branch view
$branch = $ARGV[0];
print STDERR "processing branch $branch\n";
open(BRANCH, "p4 branch -o $branch |");
@branch = <BRANCH>;
shift @branch while ($branch[0] ne "View:\n");
shift @branch;
close(BRANCH);

foreach $mapping (@branch)
{
	# process all the positive line in the mapping
	chomp;
	$mapping =~ s/^\s+//;
	next if ($mapping eq "");
	($from, $to) = split(/\s+/, $mapping);
	next if ($from =~ /^-/);

	print STDERR "processing mapping $from -> $to\n";

	undef %file;

	# read in all the deleted source files
	open(FILES, "p4 files $from |");
	$count = 0;
	print STDERR "processing files";
	while (<FILES>)
	{
		chomp;
		$count += 1;
		if ($count == 10000)
		{
			print STDERR ".";
			$count = 0;
		}
		next if (!/ - delete change /);
		s/#[^#]+//;
		$file{$_} = 1;

	}
	close(FILES);
	print STDERR "\n";

	# read in the set of source files we have.  subtract them from the list of deleted files
	open(HAVE, "p4 files $from#have |");
	$count = 0;
	print STDERR "processing have";
	while (<HAVE>)
	{
		chomp;
		$count += 1;
		if ($count == 10000)
		{
			print STDERR ".";
			$count = 0;
		}
		s/#[^#]+//;
		delete $file{$_};
	}
	close(HAVE);
	print STDERR "\n";

	print STDERR "integrating ", scalar(keys %file), " files\n";
	foreach (sort keys %file)
	{
		system("p4 integrate -b $branch -s \"$_\"");
	}
}
