#! /usr/bin/perl

use strict;
use warnings;

# ======================================================================

sub usage
{
	die "usage: $0 [--fast] [--quiet] directory ...\n" .
		"\t--fast  = do not compare file contents\n" .
		"\t--quiet = do not display identical files\n";
}

# ----------------------------------------------------------------------

sub findFiles
{
	local $_;

	my @paths = @_;
	my @localfiles;
	
	while (@paths)
	{
		my $path = shift(@paths);
		opendir(DIR, $path) || die "could not open dir $path";
			while ($_ = readdir(DIR))
			{
				next if ($_ eq "." || $_ eq "..");

				my $new = $path . "/" . $_;
				$new =~ s%\\%/%g;
				$new =~ s%//%/%g;

				if (-d $new)
				{
					push(@paths, $new);
				}
				else
				{
					push (@localfiles, $new);
				}
			}
		closedir(DIR);
	}

	return @localfiles;
}

# ======================================================================

my $quiet = 0;
my $fast = 0;

# ======================================================================

# process command line
while (@ARGV && $ARGV[0] =~ /^-/)
{
	my $arg = shift;
	
	if ($arg eq "--quiet")
	{
		$quiet = 1;
	}
	elsif ($arg eq "--fast")
		{
			$fast = 1;
		}
		else
		{
			usage();
		}
}
usage() if (@ARGV == 0);

while (@ARGV)
{
	my %files;

	# get the perforce locations for what was specified
	open(P4, "p4 where " . (shift @ARGV) . " |");
	$_ = <P4>;
	chomp;
	my ($depot, $client, $local) = split(/ /, $_, 3);
	close(P4);

	# find all the local files
	$local =~ s%\\%\/%g;
	$local =~ s%\/\.\.\.$%%;
	foreach (findFiles($local))
	{
		$files{$_} = "extra";
	}

	if ($fast)
	{ 
		# fast mode doesn't compare the contentes
		open(P4, "p4 fstat $client#have |") || die "$0: Can't open p4: $!\n";

		my $file;
		my $action;

		while (<P4>)
		{
			chomp;
			if (/^\s*$/)
			{
				if (defined($file) && defined($action))
				{
					if ($action ne "delete")
					{
						if (defined $files{$file})
						{
							# if we already knew about the file, then mark it as being in both places
							$files{$file} = "both";
						}
						else
						{
							# if we didn't know about the file, then it's missing
							$files{$file} = "missing";
						}
					}

					undef $file;
					undef $action;
				}
			}
			else
			{
				if (s%^\.\.\. clientFile %%)
				{
					s%\\%\/%g;
					$file = $_;
				}
				elsif (s%^\.\.\. headAction %%)
				{
					$action = $_;
				}
			}
		}
		close(P4)
	} 
	else
	{
		# diff is more authoritative than the file search, but we'll still keep the extra files
		open(P4, "p4 diff -sl $client |") || die "$0: Can't open p4: $!\n";
		while (<P4>)
		{
			chomp;
			my ($status, $file) = split(/ /, $_, 2);
			$file =~ s%\\%/%g;
			$files{$file} = $status;
		}
		close(P4);
	}

	foreach (sort keys %files)
	{
		my $status = $files{$_};
		print "$status $_\n" if (!$quiet || ($status ne "same" && $status ne "both"));
	}
}
