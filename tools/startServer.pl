#! /usr/bin/perl
# ======================================================================
# ======================================================================

use strict;
use warnings;

# ======================================================================
# Globals
# ======================================================================

my $scriptName = $0;
$scriptName =~ s/^(.*)[\\\/]//;

# ======================================================================
# Subroutines
# ======================================================================

sub usage()
{
	die "\nUsage:\n\t$scriptName current [ debug | release ] (default is debug)\n";
}

sub perforceWhere
{
	local $_;

	# find out where a perforce file resides on the local machine
	my $result;
	{
		open(P4, "p4 where $_[0] |");
			$_ = <P4>;
			chomp;
			my @where = split;
			$result = $where[2];
		close(P4);
	}

	return $result;
}

# ======================================================================
# Main
# ======================================================================

usage() if(@ARGV == 0 || (@ARGV >= 2 && $ARGV[1] ne "debug" && $ARGV[1] ne "release"));

my $branch = shift;
my $serverType = (@ARGV) ? shift : "debug";

# Update database
{
	chdir(perforceWhere("//depot/swg/$branch/src/game/server/database/build/linux")) or die "Cannot change directory to database directory\n";

	my $update_complete = 1;
	my $dbUser = $ENV{"USER"};
	$dbUser .= "_$branch" if($branch ne "current");

	system("perl database_update.pl --delta --username=$dbUser > startServer.log") == 0 or die "database_update failed\n";
	open(DBLOG, "startServer.log");
	while(<DBLOG>)
	{
		$update_complete = 0 if(/ERROR/);
	}
	close(DBLOG);

	die "Error while updating database - detailed info in startServer.log\n" if(!$update_complete);
	unlink("startServer.log");
}

chdir(perforceWhere("//depot/swg/$branch/bootleg/linux")) || die "Cannot chdir to ".perforceWhere("//depot/swg/$branch/bootleg/linux")."\n";

# Extract new server exes if they exist
if(-e "servers_${serverType}.tar.gz")
{
	print STDERR "Extracting new server exes...\n";
	system("tar -xzf servers_${serverType}.tar.gz") == 0 || die "error extracting from $serverType server gzip\n";
	system("rm -f servers_${serverType}.tar.gz") == 0 || die "error removing servers_${serverType}.gzip\n";
}

# Start up the server
system("$serverType/LoginServer -- \@loginServer.cfg &") == 0 || die "error starting LoginServer\n";
system("$serverType/TaskManager -- \@taskmanager.cfg &") == 0 || die "error starting TaskManager\n";
