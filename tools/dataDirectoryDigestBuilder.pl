#!/usr/bin/perl

use Digest::MD5 qw(md5_hex);

die "usage: perl buildTreeFileDigest.pl <config_file> <digest_name> [<old_digest_name>]\n" if (scalar(@ARGV) < 2 || scalar(@ARGV) > 3 || $ARGV[0] eq "-h" || $ARGV[0] eq "-?");
   
$configFile = shift;
$digest = shift;

sub numerically
{
	return ($a <=> $b);
}

sub do_directory
{
	local $_;
	my $base = $_[0];
	my $source = $_[1];
	my $name = $_[2];

	opendir(DIR, $source) || die "could not open source directory $source\n";
	my @filenames = readdir(DIR);
	closedir(DIR);
	
	for (@filenames)
	{
		next if ($_ eq "." || $_ eq "..");

		if (-d "$source/$_")
		{
			if ($name eq "")
			{
				&do_directory($base, "$source/$_", "$_");
			}
			else
			{
				&do_directory($base, "$source/$_", "$name/$_");
			}
		}
		else
		{
			$count += 1;
			print "." if ($count % 500 == 0);

			($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$source/$_");

			my $md5sum = "";
			
			if (defined $old{"$name/$_"})
			{
				($oldName, $oldPath, $oldSize, $oldTime, $oldDigest) = split(/\s+/, $old{"$name/$_"}, 5);
				if ($size == $oldSize && $mtime == $oldTime)
				{
					$md5sum = $oldDigest;
					# print "cached  $name/$_ '$md5sum'\n";
				}
				else
				{
					# print "changed $name/$_ !($size==$oldSize && $mtime==$oldTime)\n";
				}
			}
			if ($md5sum eq "")
			{
				my $buffer;
				open(FILE, "$source/$_") || die "could not spawn md5sum on file $source/$_";
					binmode FILE;
					read(FILE, $buffer, -s "$source/$_");
				close(FILE);
				$md5sum = md5_hex($buffer);
				# print "compute $name/$_ $md5sum\n";
			}
			
			$files{"$name/$_"} = "$name/$_ $base $size $mtime $md5sum";
		}
	}
}

if (@ARGV)
{
	open(DIGEST, shift) || die "could not open old digest file\n";
	while (<DIGEST>)
	{
		chomp;
		($oldName, $oldPath, $oldSize, $oldTime, $oldDigest) = split(/\s+/, $_);
		# print "caching $oldName: $_\n";
		$old{$oldName} = $_;
	}
	close(DIGEST);
}


open(CONFIG, $configFile) || die "could not open config file $configFile\n";
	while (<CONFIG>)
	{
		chomp;

		if (/searchPath/)
		{
			s/^.*searchPath//;
			s/\s+//;
			push(@paths, $_);
		}
	}
close(CONFIG);

foreach (sort numerically @paths)
{
	$count = 0;
	($priority, $path) = split(/=/);
	print "processing $path($priority)";
	do_directory($path, $path, "");
	print "\n";
}

open(DIGEST, ">$digest");
	foreach (sort keys %files)
	{
		print DIGEST $files{$_}, "\n";
	}
close(DIGEST);
