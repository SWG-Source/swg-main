use strict;
use warnings;

my $branch;
my $all = "";
my $only = "";


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
	die "usage: buildObjectTemplateCrcStringTables [--local|--all|--only <changelist#>] <current|test|live|x1|x2|ep3|demo|s#>\n" .
		"\t--local : include pending files only from the local client\n" .
		"\t--all : include pending files from all clients\n" .
		"\t--only <changelist#> : include pending files only from <changelist#>\n" .
		"\tif no option is provided, --local is assumed.\n";
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

		open(P4, "p4 opened " . $all . " " . $only . " $spec/... |");
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

if ($#ARGV == 1 || $#ARGV == 2)
{
	if ($ARGV[0] eq "--local")
	{
		$all = "";
	}
	elsif ($ARGV[0] eq "--all")
	{
		$all = "-a";
	}
	elsif ($ARGV[0] eq "--only" && $#ARGV == 2)
	{
		$all = "";
		$only = "-c " . $ARGV[1];
		shift;
	}
	else
	{
		usage();
	}

	shift;
}

usage() unless (defined($ARGV[0]) && $ARGV[0] =~ m%^(current|test|stage|live|x1|x2|ep3|demo|s\d+)$%);

$branch = $ARGV[0];

my $buildCrcStringTable = perforceWhere("//depot/swg/$branch/tools/buildCrcStringTable.pl");
{
	my $tab    = perforceWhere("//depot/swg/$branch/dsrc/sku.0/sys.client/built/game/misc/object_template_crc_string_table.tab");
	my $output = perforceWhere("//depot/swg/$branch/data/sku.0/sys.client/built/game/misc/object_template_crc_string_table.iff");
	print "building client object template strings:\n\t$tab\n\t$output\n";
	system("p4 edit $tab $output");

	my @files = perforceGatherAndPrune(
		"//depot/swg/$branch/data/sku.0/sys.shared/compiled/game/object",
		"//depot/swg/$branch/data/sku.0/sys.server/compiled/game/object/creature/player");

	open(B, "| perl $buildCrcStringTable -t $tab $output");
		foreach (@files)
		{
			print B $_, "\n";
		}
	close(B);
}

{
	my $tab    = perforceWhere("//depot/swg/$branch/dsrc/sku.0/sys.server/built/game/misc/object_template_crc_string_table.tab");
	my $output = perforceWhere("//depot/swg/$branch/data/sku.0/sys.server/built/game/misc/object_template_crc_string_table.iff");
	print "building server object template strings:\n\t$tab\n\t$output\n";
	system("p4 edit $tab $output");

	my @files = perforceGatherAndPrune(
		"//depot/swg/$branch/data/sku.0/sys.shared/compiled/game/object",
		"//depot/swg/$branch/data/sku.0/sys.server/compiled/game/object");

	open(B, "| perl $buildCrcStringTable -t $tab $output");
		foreach (@files)
		{
			print B $_, "\n";
		}
	close(B);
}
