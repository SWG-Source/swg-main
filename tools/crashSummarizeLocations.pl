# Call with the following args:
#   [-s <groupSize>] filename1 [filename 2 [...]] 
# Where:
#	<groupSize> defines the size of the square within which nearby entries will be considered to be at the same location.

use strict;

my $debug = 0;
my $groupSize = 100.0;
my %crashCountByLocation;

sub sign
{
	my $value = shift;
	if ($value >= 0)
	{
		return 1;
	}
	else
	{
		return -1;
	}
}

sub quantizeCoordinate
{
	my $coordinate = shift;
	return int(abs($coordinate)/$groupSize) * $groupSize * sign($coordinate);
}

sub addCrashLocation
{
	my $terrainName = shift;
	my $x = quantizeCoordinate(shift);
	my $y = shift;
	my $z = quantizeCoordinate(shift);

	my $key = $terrainName . ':' . $x . ':' . $z;
	++$crashCountByLocation{$key};
}

sub printCrashSummary
{
	printf("count\t%25s: %6s %6s\n\n", 'terrain file', 'x', 'z');

	# Sort entries by count, starting with highest.
	foreach my $key (sort { $crashCountByLocation{$b} <=> $crashCountByLocation{$a} } keys %crashCountByLocation)
	{
		my $count = $crashCountByLocation{$key};

		my @keyData = split(/:/, $key);
		my $terrain = $keyData[0];
		my $x = $keyData[1];
		my $z = $keyData[2];
		
		printf("%d\t%25s: %6d %6d\n", $count, $terrain, $x, $z); 	
	}
}

# Handle options.
if (defined($ARGV[0]) && ($ARGV[0] eq '-s'))
{
	shift;
	$groupSize = shift; 
}

print "group size: $groupSize\n" if $debug;	

# Process Files
my $terrain;
my $x;
my $y;
my $z;

while (<>)
{
	chomp();

	# Check for terrain
	if (s/^Terrain:\s*//)
	{
		$terrain = $_;	
	}
	elsif (m/^Player:\s*(\S+)\s+(\S+)\s+(\S+)/)
	{
		$x = $1;
		$y = $2;
		$z = $3;
		
		# This line depends on the Player entry coming after the Terrain entry in a .txt file.
		addCrashLocation($terrain, $x, $y, $z);
	}
}

printCrashSummary;

