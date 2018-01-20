use strict;
use warnings;

# redirect stderr to stdout
open STDERR, ">&STDOUT";

die "usage: $0 [OutputDirectory]\n" if (@ARGV != 1 || $ARGV[0] =~ /^[-\/]/);

# check if this is a publich build
my $brand = $ENV{"APPLICATION_VERSION_BRAND"};
exit 0 if (!defined $brand);

$brand =~ /^(\d+)\.(\d+)/;
my $publish = $1;
my $attempt = $2;

# split the build number up into its pieces
my $publishHigh = int($brand / 1000);
my $publishLow  = int($brand % 1000);
my $attemptHigh = int($attempt / 1000);
my $attemptLow  = int($attempt% 1000);


# read in the RC file and generate the new version number text
my $rcFile = "..\\..\\src\\win32\\SwgClient.rc";
open(F, $rcFile);
my $rcText = "";
my $updatedRcText = "";
while (<F>)
{
	$rcText .= $_;
	s/\d+,\d+,\d+,\d+/$publishHigh,$publishLow,$attemptHigh,$attemptLow/ if (/version/i);
	s/\d+, \d+, \d+, \d+/$publishHigh, $publishLow, $attemptHigh, $attemptLow/ if (/version/i);
	$updatedRcText .= $_;
}
close(F);

# if the RC changed, write it out and rebuild only the clients
if ($updatedRcText ne $rcText)
{
	# write out the RC file
	print "Updating and recompling resource file...\n";
	if (!open(F, ">" . $rcFile))
	{
		print "could not open $rcFile for writing\n";
		die;
	}

	print F $updatedRcText;
	close(F);

	if (system("rc /Fo $ARGV[0]\\SwgClient.res ..\\..\\src\\win32\\SwgClient.rc") != 0)
	{
		print "resource compiliation failed\n";
		die;
	}
}
else
{
	print "Resource file was not changed\n";
}
