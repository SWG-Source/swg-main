#! /usr/bin/perl
# ======================================================================
# ======================================================================

use warnings;
use strict;
use Socket;

# ======================================================================
# Constants
# ======================================================================

use constant START_BOOTLEG_TEST => "A";
use constant END_COMMUNICATION => "B";
use constant SUCCESSFUL_TEST => "C";
use constant UNSUCCESSFUL_TEST => "D";
use constant SERVER_READY => "E";
use constant BOOTLEG_MISMATCH => "F";
use constant CLIENT_KILL => "G";
use constant CLIENT_OK => "H";
use constant GOT_BUILD_CLUSTER_VERSION => "I";
use constant FAILED_GETTING_BUILD_CLUSTER_VERSION => "J";
use constant START_UPKEEP => "K";
use constant START_BOOTLEG_SEND => "L";
use constant BOOTLEG_SEND_DIRECTORY => "M";
use constant BOOTLEG_SEND_FILE => "N";
use constant END_BOOTLEG_SEND => "O";
use constant START_EMAIL => "P";

# ======================================================================
# Globals
# ======================================================================

my $name = $0;
$name =~ s/^(.*)\\//;
	
my $branch;
my $numbootlegs = 7;
my $pdbtime = 14;
my $bootlegnum = "";
my $waittime = "60";
my $port = "21498";
my $build_cluster = "lin-vthakkar.station.sony.com";
my $candela = "p:";

# ======================================================================
# Subroutines
# ======================================================================

sub usage
{
	die "\n\t$name\n\n";
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

sub reloop
{
	print STDERR "Error with: $_[0]\n" if(defined $_[0]);
	print STDERR "Exiting this connection\n";
	goto FAIL;
}

sub installBootleg
{
	print "Installing bootleg...\n";

	open(INSTALL, "perl " . perforceWhere("//depot/swg/current/tools/InstallBootleg.pl") . " --list --force_newest --client_only --no_database $branch |") or reloop "Error running InstallBootleg.pl\n";
	
	my $complete = 0;
	
	while(<INSTALL>)
	{
		print;
		$bootlegnum = $1 if(/^Updating to build: (\d+)/);
		$complete = 1 if(/^Update complete/);	
	}
	
	close(INSTALL);	
	
	print "Bootleg installation incomplete\n" if(!$complete);
	print "Completed installing bootleg.\n" if($complete);
	
	return $complete; 
}

sub error
{
	my $message = shift @_;
	print SOCKET UNSUCCESSFUL_TEST;
	print STDERR "$message\n";
	goto FAIL;
}

sub fatal
{
	my $message = shift @_;
	print SOCKET UNSUCCESSFUL_TEST;
	close(SOCKET);
	die "$message\n";
}

sub makeDir
{
	my(@tok, $check);
	@tok = split(/\\|\//, $_[0]);
	
	$check = shift(@tok);
	foreach (@tok) 
	{
		$check .= "/$_";
		if(!(-d $check))
		{
			mkdir $check;
		}
	}
	
}

sub recieveBootleg
{
	my $buffer;

	return 0 if (read(SOCKET, $buffer, 4) != 4);
	my $length = unpack("N", $buffer);
	return 0 if(read(SOCKET, $branch, $length) != $length);
	return 0 if (read(SOCKET, $buffer, 4) != 4);
	$bootlegnum = unpack("N", $buffer);
	
	print STDERR "Recieving bootleg $branch/$bootlegnum...\n";
	
	my $directory = "";
	while(1)
	{
		return 0 if (read(SOCKET, $buffer, 1) != 1);
		last if($buffer eq END_BOOTLEG_SEND);
		
		if($buffer eq BOOTLEG_SEND_DIRECTORY)
		{
			return 0 if (read(SOCKET, $buffer, 4) != 4);
			$length = unpack("N", $buffer);
			return 0 if (read(SOCKET, $directory, $length) != $length);
			makeDir("$candela/SWO/swg_bootleg_builds/$branch/$bootlegnum/$directory");
			chdir("$candela/SWO/swg_bootleg_builds/$branch/$bootlegnum/$directory") || reloop "Cannot chdir to $branch/$bootlegnum/$directory - $!\n";
		}
		if($buffer eq BOOTLEG_SEND_FILE)
		{
			return 0 if (read(SOCKET, $buffer, 2*4) != 2*4);
			my ($fileNameLength, $fileSize) = unpack("NN", $buffer);
			my $localFileName;
			return 0 if (read(SOCKET, $localFileName, $fileNameLength) != $fileNameLength);
			
			print STDERR "Receiving $branch/$bootlegnum/$directory/$localFileName ($fileSize bytes)\n";
			open(F, ">$localFileName") || reloop ("could not open $localFileName for writing");
				chmod (0755, $localFileName);
				binmode(F);
				while ($fileSize)
				{
					my $readSize = 16 * 1024;
					$readSize = $fileSize if ($fileSize < $readSize);
					my $readResult = read(SOCKET, $buffer, $readSize);
					reloop "socket to controller machine abruptly terminated ($fileSize bytes remained)\n" if (!defined($readResult));
					reloop "read incorrect amount ($fileSize bytes remained)\n" if ($readResult == 0);
					print F $buffer;
					$fileSize -= $readResult;
				}
			endbootleginstall("copied wrong number of bytes") if ($fileSize != 0);		
			close(F);
		}
	}
	
	chdir("$candela/SWO/swg_bootleg_builds") || reloop "Cannot chdir to $candela - $!\n";;
	
	print STDERR "Completed recieving bootleg $branch/$bootlegnum...\n";
}

sub testBootleg
{
	my $buffer;
	print STDERR "Initializing communication...\n";

	error("problem reading from socket") if (read(SOCKET, $buffer, 4) != 4);
	my $length = unpack("N", $buffer);
	error("problem reading from socket") if(read(SOCKET, $branch, $length) != $length);
		
	print STDERR "Testing bootleg for branch: $branch\n";

	my $bootlegdir = perforceWhere("//depot/swg/$branch/bootleg/win32/...");
	$bootlegdir =~ s/\.{3}//;

	chdir($bootlegdir) or reloop "Cannot change to bootleg directory\n";

	installBootleg() || fatal "Error installing bootleg";
		
	print SOCKET pack("N", $bootlegnum);
		
	error("problem reading from socket") if (read(SOCKET, $buffer, 1) != 1);
	error("mismatch in client / server bootlegs")if($buffer eq BOOTLEG_MISMATCH);
	error("server not ready") if ($buffer ne SERVER_READY);
	print STDERR "Bootleg $bootlegnum verified with server - running client...\n";
		
	my $killresult;
	my $swgpid = open(SWGCLIENT, "SwgClient_o.exe -- -s ClientGame loginServerAddress=$build_cluster skipIntro=true skipSplash=true autoConnectToLoginServer=true loginClientID=bootleg loginClientPassword=bootleg avatarName=\"bootleg bootleg\" autoConnectToGameServer=true autoQuitAfterLoadScreen=true -s SharedFoundation demoMode=true |");
	error("problem reading from socket") if (read(SOCKET, $buffer, 1) != 1);
	if($buffer eq CLIENT_KILL)
	{
		kill 1, $swgpid;
		error("Test unsuccessful - forced to kill client");
	}
	elsif($buffer eq CLIENT_OK)
	{
		# make sure we give the client a chance to exit on its own, then attempt to kill
		print "Waiting for $waittime seconds for the client to end on its own...\n";
		sleep($waittime);
		$killresult = kill 1, $swgpid;
	}
	close(SWGCLIENT);
		
	# clientResult = 1 if return value of SwgClient == 0 and we did not have to kill it ($killresult = 0)
	my $clientResult = (!($? >> 8) && !$killresult);
	print "clientresult=$clientResult killresult=$killresult exitresult=$?\n";
			
	print SOCKET ($clientResult == 1) ? SUCCESSFUL_TEST : UNSUCCESSFUL_TEST;
	
	if($clientResult == 1)
	{
		open(BLESS, ">$candela/SWO/swg_bootleg_builds/$branch/$bootlegnum/blessed.txt");
		close(BLESS);
	}
	
	print STDERR "Test was " . (($clientResult == 1) ? "successful\n" : "unsuccessful\n") . "\n";
}


sub upkeep
{
	my $buffer;

	return 0 if (read(SOCKET, $buffer, 4) != 4);
	my $length = unpack("N", $buffer);
	return 0 if(read(SOCKET, $branch, $length) != $length);
		
	print STDERR "Performing upkeep on bootleg directory for $branch...\n";

	my @bootlegs;
	my $removedbootlegs = 0;
	my $buildcluster;
	
	print STDERR "Getting bootleg version on build cluster...\n";
	my $controller = perforceWhere("//depot/swg/current/tools/build_cluster_controller.pl");
			
	open(BUILD, "perl $controller -bootleg-version 2>&1 |");
	while(<BUILD>)
	{
		$buildcluster = $1 if(/^Build cluster bootleg version is: (\d+)/);
	}		
	close(BUILD);
			
	if(!defined $buildcluster)
	{
		print STDERR "Could not get build cluster bootleg version.\n";
		print SOCKET FAILED_GETTING_BUILD_CLUSTER_VERSION;
		return 0;
	}
	else
	{
		print STDERR "Build cluster bootleg version is $buildcluster.\n";
		print SOCKET GOT_BUILD_CLUSTER_VERSION;
		print SOCKET pack("N", $buildcluster);	
	}
	
	opendir DH, "$candela/SWO/swg_bootleg_builds/$branch" or fatal "Cannot open $candela/SWO/swg_bootleg_builds/$branch: $!\n";
	foreach (readdir DH)
	{
		push @bootlegs, $_ if(/^\d+$/ && -d ("$candela/SWO/swg_bootleg_builds/$branch/$_"));
	}
	closedir DH;	
	
	@bootlegs = sort { $a <=> $b } @bootlegs; 
	
	while(@bootlegs > $numbootlegs)
	{
		my $bootleg = shift @bootlegs;
		next if($buildcluster == $bootleg);
		
		print STDERR "Removing bootleg $bootleg...\n";
		system("rm -fr $candela/SWO/swg_bootleg_builds/$branch/$bootleg");
		print SOCKET pack("N", $bootleg);
		++$removedbootlegs;
	}
	print SOCKET pack("N", 0);
	print STDERR "Completed upkeep on bootleg directory - removed $removedbootlegs bootlegs.\n";
	
	my $removedpdbs = 0;
	print STDERR "Performing upkeep on pdb directory...\n";
	opendir DH, "$candela/SWO/pdbs" or fatal "Cannot open $candela/SWO/pdbs: $!\n";
	foreach (sort readdir DH)
	{
		my $pdbfile = $_;
		if($pdbfile =~ /^\d+_0_$branch\.zip$/ && -M "$candela/SWO/pdbs/$pdbfile" > $pdbtime)
		{
			print STDERR "Deleting $pdbfile...\n";
			#system("rm -f $candela/SWO/pdbs/$pdbfile");
			print SOCKET pack("N", length $pdbfile);
			print SOCKET $pdbfile;
			++$removedpdbs;
		}
	}
	closedir DH;	
	print SOCKET pack("N", 0);
	
	print STDERR "Completed upkeep on pdb directory - removed $removedpdbs pdbs.\n\n";
	return 1;
}

sub endEmail
{
	print SOCKET pack("N", 0);
	return 0;
}

sub bootlegDirDescending
{
	my($a, $b) = @_;
	
	# Both are numbers
	return $b <=> $a if($a =~ /^\d+$/ && $b =~ /^\d+$/);

	# Both are not numbers
	return $a cmp $b if(!($a =~ /^\d+$/) && !($b =~ /^\d+$/));

	# $a is a number, $b is not
	return -1 if($a =~ /^\d+$/);
	
	# $a is not a number, $ b is
	return 1;
}

sub email
{
	my $currentBootleg = "";
	my $oldBootleg = "";
	my $buffer;
	return endEmail() if(read(SOCKET, $buffer, 4) != 4);
	my $currentBootlegLength = unpack("N", $buffer);
	return endEmail() if($currentBootlegLength == 0);
	return endEmail() if(read(SOCKET, $currentBootleg, $currentBootlegLength) != $currentBootlegLength);

	opendir DH, "$candela/SWO/swg_bootleg_builds/$branch" or fatal "Cannot open $candela/SWO/swg_bootleg_builds/$branch: $!\n";
	foreach (sort { bootlegDirDescending($b, $a) } readdir DH)
	{
		# we want the 1st blessed one that is not the one we are looking at
		next if($currentBootleg eq $_);
		
		if(/^\d+$/ && -d "$candela/SWO/swg_bootleg_builds/$branch/$_" && -f "$candela/SWO/swg_bootleg_builds/$branch/$_/blessed.txt")
		{
			$oldBootleg = $_;
			last;
		}
	}
	closedir DH;	
	
	print SOCKET pack("N", length $oldBootleg);
	print SOCKET $oldBootleg;
	
	print STDERR "Completed sending information to build_bootleg_linux.\n";
}

# ======================================================================
# Main
# ======================================================================

# open the daemon socket
print STDERR "Opening socket\n";
socket(LISTEN, PF_INET, SOCK_STREAM, getprotobyname('tcp')) || die "socket failed\n";
setsockopt(LISTEN, SOL_SOCKET, SO_REUSEADDR, 1) || die "setsockopt failed\n";
my $addr = sockaddr_in($port, INADDR_ANY);
bind(LISTEN, $addr) || die "bind failed\n";
listen(LISTEN, 1) || die "listen failed\n";

BUILDLOOP:
while (1)
{
	print STDERR "Waiting on a connection...\n";
	
	accept(SOCKET, LISTEN) || reloop "accept failed\n";

	# make binary and unbuffer the socket
	binmode(SOCKET);	
	my $oldSelect = select(SOCKET);
	$| = 1;
	select($oldSelect);

	my $buffer;
	error("problem reading from socket") if (read(SOCKET, $buffer, 1) != 1);

	if($buffer eq START_BOOTLEG_TEST)
	{
		print "Got message to initiate bootleg test.\n";
		testBootleg();
	}
	elsif($buffer eq START_UPKEEP)
	{
		print "Got message to perform upkeep.\n";
		upkeep();
	}
	elsif($buffer eq START_BOOTLEG_SEND)
	{
		print "Got message to start recieving bootleg.\n";
		recieveBootleg();
	}	
	elsif($buffer eq START_EMAIL)
	{
		print "Got message to start email.\n";
		email();
	}
FAIL:
	close(SOCKET);
}