use warnings;
use strict;
use Compress::Zlib;

sub numerically
{
	return $a <=> $b;
}

die "usage: $0 changelist [changelist ...]" if (@ARGV == 0 || $ARGV[0] =~ /^[-\/]/);

my $debug = 0;

my %size;
my %files;
foreach my $changelist (sort numerically @ARGV)
{

	print STDERR "describing $changelist\n" if ($debug);
	open(P4, "p4 -ztag describe -s $changelist|") || die "could not describe $changelist\n";
	my $depotFile;
	while (<P4>)
	{
		chomp;
		if (s/^\.\.\. depotFile\d+ //)
		{
			$depotFile = $_ if (m%/data/%);
		}
		elsif (defined $depotFile && s/^\.\.\. action\d+ //)
		{
			if ($_ eq "delete")
			{
				print "  ", $depotFile, " **DELETED**\n" if ($debug);
				delete $files{$depotFile} if defined($files{$depotFile});
				undef $depotFile;
			}
		}
		elsif (defined $depotFile && s/^\.\.\. rev\d+ //)
		{
			$files{$depotFile} = $_;
			print "  ", $depotFile, "#", $_, "\n" if ($debug);
			undef $depotFile;
		}
	}
	close(P4);
}

my @files = sort keys %files;
die "no files to patch in changelists\n" if (@files== 0);

print STDERR "syncing\n" if ($debug);
open(P4, "| p4 -x - sync 2> nul");
foreach (@files)
{
	print P4 "  ", $_, "#", $files{$_}, "\n";
}
close(P4);

print STDERR "fstat\n" if ($debug);
foreach my $file (@files)
{
	print STDERR "  fstat $file\n" if ($debug);
	open(P4, "p4 fstat $file |") || die "could not fstat $file\n";
	while (<P4>)
	{
		chomp;

		if (s/^\.\.\. clientFile //)
		{
			my $size = -s $_;

			if (/\.wav$/ || /\.mp3$/)
			{
				# wav and mp3 files remain uncompressed
				$size{$_} = $size;
			}
			else
			{
				print STDERR "  reading $file\n" if ($debug);
				my $contents;
				open(FILE, $_) || die "could not open file $_\n";
					binmode FILE;
					read(FILE, $contents, $size);
				close(FILE);

				print STDERR "  compressing $file\n" if ($debug);
				my $compressor = deflateInit();
				my $compressed = $compressor->deflate($contents);
				$compressed .= $compressor->flush();
				$size{$_} = (length($compressed) < $size) ? length($compressed) : $size;
			}
		}
	}
	close(P4);
}

# total up the output
my $total = 0;
my $count = 0;
foreach (keys %size)
{
	$total += $size{$_};
	++$count;
}

# choose the appropriate units for the output
my $extension = "bytes";
my $format = "%0.0f";
if ($total > 1024)
{
	$extension = "kb";
	$total /= 1024;
	$format = "%0.2f";
}
if ($total > 1024)
{
	$extension = "mb";
	$total /= 1024;
}

print "estimate patch size ", sprintf($format, $total), " $extension ($count files)\n";
