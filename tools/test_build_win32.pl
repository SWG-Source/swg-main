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

# ======================================================================
# Globals
# ======================================================================

my $scriptName = $0;
$scriptName =~ s/^(.*)\\//;
	
my $branch;
my $bootlegnum = "";
my $waittime = "60";
my $port = "98514";

# ======================================================================
# Subroutines
# ======================================================================

sub usage
{
	die "\n\t$scriptName\n\n";
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

	open(INSTALL, "perl " . perforceWhere("//depot/swg/current/tools/InstallBootleg.pl") . " --list --force_newest --client_only $branch |") or reloop "Error running InstallBootleg.pl\n";
	
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
		
	# Get the ip of the server machine
	my $other_socket = getpeername(SOCKET) || reloop "Couldn't identify other end: $!\n";
	my ($other_port, $other_ip) = unpack_sockaddr_in($other_socket);
	my $server_ip = inet_ntoa($other_ip);
		
	my $killresult;
	my $swgpid = open(SWGCLIENT, "SwgClient_o.exe -- -s ClientGame loginServerAddress=$server_ip skipIntro=true skipSplash=true autoConnectToLoginServer=true loginClientID=bootleg loginClientPassword=bootleg avatarName=\"bootleg bootleg\" autoConnectToGameServer=true autoQuitAfterLoadScreen=true -s SharedFoundation demoMode=true |");
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
	
	print STDERR "Test was " . (($clientResult == 1) ? "successful\n" : "unsuccessful\n") . "\n";
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
FAIL:
	close(SOCKET);
}