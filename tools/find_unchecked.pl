#!/usr/bin/perl

use File::Find;

# process command line arguments
while ($ARGV[0] =~ /^-/)
{
	$_ = shift;
	
	if ($_ eq "--debug")
	{
		$debug = 1;
	}
	elsif ($_ eq "--delete")
	{
		$delete = 1;
	}
	else
	{
		die "unknown command line option";
	}
}

sub CollectP4OpenedFiles
{
	open(P4, "p4 opened |");
	while (<P4>)
	{
		chomp;
		$openedFiles{$_} = 1 if (s/#.*//);
	}
	close(P4);
}

sub FindHandler 
{
	if (-d $_)
	{
		# found a directory entry

		# prune the directory if it's one we want to ignore
		if (m/^(compile|external|Debug|Optimized|Production|Release|generated)$/)
		{
			# prune it
			$File::Find::prune = 1;
			print STDERR "[Pruned Directory Entry: $File::Find::name]\n" if ($debug);
		}
	}
	elsif (-f and -w $_)
	{
		# handle writable non-directory entry
		if (!m/^.*(\.(aps|ca|clw|class|dll|ews|exe|ncb|opt|plg|WW|tmp|db|bak|pyc|cfg|o)|~)$/)
		{
			# this is a writable file that should be checked against what's in Perforce.
			my ($commandLine, $expectedDepotLocation);

			$commandLine = `p4 where $File::Find::name`;
			$commandLine =~ /([^ ]+) /;

			$expectedDepotLocation = $1;

			# this writable file is suspect (i.e. is missing) if the depot file
			# is not opened.  That implies the file is writable but not opened,
			# most likely indicating it doesn't exist in the depot.
			if (!$openedFiles{$expectedDepotLocation})
			{
				print $File::Find::name, "\n";
				unlink $File::Find::name if ($delete);
			}
			else
			{
				print STDERR "<file [$File::Find::name] is in perforce>\n" if ($debug);
			}
		}
	}
}

# collect opened depot files
CollectP4OpenedFiles();

# do a find
@ARGV = ('../') unless @ARGV;
find(\&FindHandler, @ARGV);
