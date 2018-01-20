use strict;
use warnings;

my $branch;


# =====================================================================

sub perforceWhere
{
	# find out where a perforce file resides on the local machine
	my $result;
	{
		open(P4, "p4 where $_[0] |");
			while ( <P4> )
			{
				next if ( /^-/ );
				chomp;
				my @where = split;
				$result = $where[2];
			}
		close(P4);
	}

	return $result;
}

sub usage
{
	die "usage: $0 <branch> <output>\n";
}

# =====================================================================

sub perforceGatherAndPrune
{
	local $_;
	my %files;
	
	foreach my $spec (@_)
	{
		open(P4, "p4 files $spec/... |");
		while (<P4>)
		{
			chomp;
			next if (/ delete /)/
			s%//depot/swg/$branch/data/sku\.0/sys\.(shared|server)/compiled/game/%%;
			s/#.*//;
			$files{$_} = 1;
		}
		close(P4);

		open(P4, "p4 opened -a $spec/... |");
		while (<P4>)
		{
			chomp;
			s%//depot/swg/$branch/data/sku\.0/sys\.(shared|server)/compiled/game/%%;
			s/#.*//;
			$files{$_} = 1;
		}
		close(P4);
	}

	return sort keys %files;
}

# =====================================================================

usage() unless (@ARGV == 2 && $ARGV[0] =~ m%^(current|test|live|x1|x2|s0|s1|s2|s3|s4|s5)$%);

$branch = $ARGV[0];
my $output = $ARGV[1];

{
	my @files = perforceGatherAndPrune("//depot/swg/$branch/data/sku.0/sys.shared/compiled/game/object");

	open(B, ">" . $output);
		foreach (@files)
		{
			print B "/rem object createAt ", $_, "\n";
		}
	close(B);
}

