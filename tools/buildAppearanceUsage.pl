#! /usr/bin/perl

die "usage: perl buildAppearanceUsage buildAppearanceTableOutputFile directory [directory ...]\n" if (@ARGV == 0 || $ARGV[0] eq "-h");

$debug = 0;

# recursively scan a directory
sub do_dir
{
	local $_;
	my $real = $_[0];
	my $display = $_[1];

	print STDERR "processing $real\n" if ($debug);
	
	opendir(DIR, $real) || return;
	my @filenames = readdir(DIR);
	closedir(DIR);
	
	for (@filenames)
	{
		next if $_ eq ".";
		next if $_ eq "..";

		
		if (-d "$real/$_")
		{
			if ($display ne "")
			{		
				&do_dir("$real/$_", "$display/$_");
			}
			else
			{
				&do_dir("$real/$_", "$_");
			}
		}
		elsif (/\.apt$/)
		{
			$add = "$display/$_";
			$add =~ s#^.*/appearance/#appearance/#;
			print STDERR "adding file $add\n" if ($debug);
			$apt{"$add"} = 0;
		}
	}
}

$output = shift @ARGV;

# process all the command line directories
while (@ARGV)
{
	&do_dir(shift @ARGV, "");
}

open(FILE, $output);
while (<FILE>)
{
	chomp;
	($object, $appearance) = split(/\t+/);
	$apt{$appearance} += 1;
}
close(FILE);

# spit out tab separated data
foreach (sort keys %apt)
{
	print $apt{$_}, "\t", $_, "\n";
}
