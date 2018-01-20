#! /usr/bin/perl

die "usage: perl buildAppearanceTable directory [directory ...]\n" if (@ARGV == 0 || $ARGV[0] eq "-h");

$debug = 0;

# scan the file looking for an appearance or portal layout name
sub do_file
{
	local $_;
	my $file = $_[0];

	print STDERR "scanning $file\n" if ($debug);
	
	open(FILE, $file);
	while (<FILE>)
	{
		chomp;
		
		if (/appearanceFilename/ || /portalLayoutFilename/)
		{
			s/^[^"]+"//;
			s/"[^"]*$//;

			tr/A-Z/a-z/;
			tr#\\#/#;
			$match{$file} = $_ if ($_ ne "");

			print STDERR "match $file $_\n" if ($debug);
		}
	}
	close(FILE);
}

# recursively scan a directory
sub do_dir
{
	local $_;
	my $dir = $_[0];

	print STDERR "processing $dir\n" if ($debug);
	
	opendir(DIR, $dir) || return;
	my @filenames = readdir(DIR);
	closedir(DIR);
	
	for (@filenames)
	{
		next if $_ eq ".";
		next if $_ eq "..";

		$pathed = $dir . "/" . $_;
		
		if (-d $pathed)
		{
			&do_dir($pathed);
		}
		elsif (/\.tpf$/)
		{
			&do_file($pathed);
		}
	}
}

# process all the command line directories
while (@ARGV)
{
	&do_dir(shift @ARGV);
}

# spit out tab separated data
foreach (sort keys %match)
{
	print $_, "\t", $match{$_}, "\n";
}
