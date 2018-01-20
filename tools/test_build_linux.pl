#! /usr/bin/perl
# ======================================================================
# ======================================================================

use warnings;
use strict;
use Socket;
use Getopt::Long;
use File::Copy;

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

my $depotdir = "/swg";
my $builddir = "/mnt/misc/builds";
my $logfile = "test_build.log";
my $win32machine = "64.37.133.173";
my $port = "98514";
my $emailRecipients = "vthakkar\@soe.sony.com";

my $waittime = "180";
my $branch = "";
my $oldbootleg = "";
my $newbootleg = "";
my $loginpid;
my $taskpid;

my $numbootlegs = 7;

my @steps = (0, 0, 0, 0);

# ======================================================================
# Subroutines
# ======================================================================

sub usage
{
	print "\n\t$scriptName <optional parameters> <branch>\n\n".
		"\tOptional parameters:\n\n".
		"\t\t--install\t: Install newest build\n".
		"\t\t--test\t\t: Test build\n".
		"\t\t--email\t\t: Send email about results\n".
		"\t\t--upkeep\t: Perform upkeep on bootleg directories\n";
	die "\n";
}

sub writelog
{
	my $message = shift @_;
	chomp $message;
	my ($sec, $min, $hr, $day, $mon, $yr) = localtime time;
	my $timestamp = sprintf "%4s-%02s-%02s\t%02s:%02s:%02s", ($yr + 1900), ($mon + 1), $day, $hr, $min, $sec;

	print LOG join("\t", $timestamp, $message), "\n";
}

sub fatal
{	
	my $message = shift @_;
	print "Fatal error running: $message\n";
	writelog("Fatal error running: $message");
	close(LOG);
	die;
}

sub unbuffer
{
	my $oldSelect = select($_[0]);
	$| = 1;
	select($oldSelect);
}

sub unbufferReadline
{
	my ($fh) = @_;
	my $buffer;
	my $return = "";
	while(sysread($fh, $buffer, 1))
	{
		$return .= $buffer;
		last if($buffer eq "\n");
	}
	return $return;
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


sub openClientSocket
{
	socket(SOCKET, PF_INET, SOCK_STREAM, getprotobyname('tcp')) || closeServer("socket failed\n");
	{
		my $destination = inet_aton($win32machine) || closeServer("inet_aton failed\n");
		my $paddr = sockaddr_in($port, $destination);
		connect(SOCKET, $paddr) || closeServer("connect failed\n");

		# unbuffer the socket
		my $oldSelect = select(SOCKET);
		$| = 1;
		select($oldSelect);

		# put the socket into binary mode
		binmode SOCKET;
	}
}

sub getCurrentBootleg
{
	my $bootleg = 0;
	
	open(VER, perforceWhere("//depot/swg/$branch/tools/VersionNumber") . " -r ".perforceWhere("//depot/swg/$branch/bootleg/linux/debug/lib/libsharedFoundataion.so")." |");
	while(<VER>)
	{
		$bootleg = $1 if(/\s(\d+)\.0 bootleg/);
	}	
	close(VER);
	
	return $bootleg;
}


sub installBootleg
{
	print "Installing bootleg...\n";
	writelog("Installing bootleg");

	open(INSTALL, "perl " . perforceWhere("//depot/swg/current/tools/InstallBootleg.pl") . " --list --force_newest --server_only --install_as_build_cluster --update_database $branch |") or fatal "Error running InstallBootleg.pl\n";
	
	my $complete = 0;
	
	while(<INSTALL>)
	{
		print;
		writelog($_);
		$complete = 1 if(/^Update complete\./);	
		$oldbootleg = $1 if($oldbootleg eq "" && /^\d+\s+(\d+)\s+blessed/);
		$newbootleg = $1 if(/^Updating to build: (\d+)/);
	}
	
	close(INSTALL);	

	print "Bootleg installation incomplete\n" if(!$complete);
	print "Completed installing bootleg.\n\n" if($complete);
	writelog("OldBootleg: $oldbootleg, InstallBootleg complete: $complete");
	
	return $complete; 
}

sub closeServer
{
	print "Fatal Error: Killing forked processes\n";
	endServer();
	fatal $_[0];
}

sub startServer
{
        my $loginServer = "debug/LoginServer";
	my $taskManager = "debug/TaskManager";

	writelog("Starting Server");
	my $serverdir = perforceWhere("//depot/swg/$branch/bootleg/linux/fakefile");
	$serverdir =~ s/fakefile$//;
	chdir($serverdir) || fatal "Cannot change directory to $serverdir\n";

	print "Starting up server...\n";
	$loginpid = open(LOGINSERVER, "$loginServer -- \@loginServer.cfg 2>&1 |") or closeServer("Can't open LoginServer\n");
	binmode LOGINSERVER;
	
	while(<LOGINSERVER>)
	{
		writelog("LoginServer: $_") if(/\S+/);
		last if(/^Cluster \d+:/);
	}	
	
	$taskpid = open(TASKMANAGER, "$taskManager -- \@taskmanager.cfg 2>&1 |") or closeServer("Can't open TaskManager\n");
	binmode TASKMANAGER;

	while(<TASKMANAGER>)
	{
		writelog("TaskManager: $_") if(/\S+/);
		last if(/^Preload finished on all planets/);
	}	
}

sub endServer
{
	writelog("Ending Server");
	print "Shutting down server.\n";
	kill 1, $taskpid if(defined $taskpid);
	kill 1, $loginpid if(defined $loginpid);
	system("killall CommoditiesServer");
	system("killall ChatServer");
	close(TASKMANAGER);
	close(LOGINSERVER);
}

sub startClient
{
	writelog("Starting Client");
	print "Starting up client...\n";

	openClientSocket();

	print SOCKET START_BOOTLEG_TEST;
	print SOCKET pack("N", length $branch);
	print SOCKET $branch;	
}

sub endClient
{	
	writelog("Ending Client");
	print SOCKET CLIENT_KILL;
	print "Shutting down client.\n";
	close(SOCKET);
}

sub checkResponses
{
	writelog("Verifying server and client responses");
	my $loginsuccess = 0;
	my $tasksuccess = 0;
	my $buffer;
	
	print "Verifying client and server have same bootleg installation.\n";
	read(SOCKET, $buffer, 4) == 4 or fatal "Error reading from win32 machine\n";
	my $clientbootleg = unpack("N", $buffer);
	
	$newbootleg = getCurrentBootleg() if(!defined $newbootleg);
	
	if($clientbootleg ne $newbootleg)
	{
		writelog("Mismatch in client / server bootlegs - client: $clientbootleg, server: $newbootleg");
		print "Mismatch in client / server bootlegs - client: $clientbootleg, server: $newbootleg\n";
		print SOCKET BOOTLEG_MISMATCH;
		return 0;
	}
	print "Both client and server have bootleg $newbootleg installed\n";
	writelog("Both client and server have bootleg $newbootleg installed");
	
	print SOCKET SERVER_READY;

	my $starttime = time;
	writelog("Beginning test with client - timeout of $waittime seconds");
	
	# used to create non-blocking reading of both filehandles
	while(1)
	{
		my $rin = '';
		my $rout;
		my $line;
		vec($rin, fileno(LOGINSERVER), 1) = 1;
		vec($rin, fileno(TASKMANAGER), 1) = 1;

		if(select($rout=$rin, undef, undef, 0))
		{
			if (vec($rout, fileno(LOGINSERVER), 1)) 
			{ 
				$line = unbufferReadline(\*LOGINSERVER);
				if(defined $line)
				{
					writelog("LoginServer: $line") if($line =~ /\S+/);
					++$loginsuccess if($loginsuccess == 0 && $line =~ /^connection opened for service on port \d+/);
					++$loginsuccess if($loginsuccess == 1 && $line =~ /^Encrypting with key:/);
					++$loginsuccess if($loginsuccess == 2 && $line =~ /^Client connected\.  Station Id:  \d+, Username: bootleg/);
					++$loginsuccess if($loginsuccess == 3 && $line =~ /^Client \d+ disconnected/);

					last if ($line =~ /ERROR/ or $line =~ /FATAL/);
				}
			}
			if (vec($rout, fileno(TASKMANAGER), 1)) 
			{
				$line = unbufferReadline(\*TASKMANAGER);
				if(defined $line)
				{
					writelog("TaskManager: $line") if($line =~ /\S+/);
					++$tasksuccess if($tasksuccess == 0 && $line =~ /^connection opened for service on port \d+/);
					++$tasksuccess if($tasksuccess == 1 && $line =~ /^Opened connection with client/);
					++$tasksuccess if($tasksuccess == 2 && $line =~ /^Recieved ClientIdMsg/);
					++$tasksuccess if($tasksuccess == 3 && $line =~ /^Decrypting with key: /);
					++$tasksuccess if($tasksuccess == 4 && $line =~ /^succeeded/);
					++$tasksuccess if($tasksuccess == 5 && $line =~ /^ValidateAccountMessage/);
					++$tasksuccess if($tasksuccess == 6 && $line =~ /^ValidateAccountReplyMessage/);
					++$tasksuccess if($tasksuccess == 7 && $line =~ /^Permissions for \d+:/);
					++$tasksuccess if($tasksuccess == 8 && $line =~ /canLogin/);
					++$tasksuccess if($tasksuccess == 9 && $line =~ /canCreateRegularCharacter/);
					++$tasksuccess if($tasksuccess == 10 && $line =~  /^Recvd SelectCharacter message for \d+/);
					++$tasksuccess if($tasksuccess == 11 && $line =~  /^Got ValidateCharacterForLoginMessage acct \d+, character \d+/);
					++$tasksuccess if($tasksuccess == 12 && $line =~  /^Pending character \d+ is logging in or dropping/);

					last if ($line =~ /ERROR/ or $line =~ /FATAL/);
				}
			}
		}

		return 0 if((time - $starttime) > $waittime);
		last if($loginsuccess == 4 && $tasksuccess == 13);
	}
	
	writelog("LoginServer success: $loginsuccess/4, Taskmanager success: $tasksuccess/13");
	return 0 if($loginsuccess != 4 || $tasksuccess != 13);
	
	# Tell win32 machine that the client is ok (don't need to kill it)
	print SOCKET CLIENT_OK;
	
	read(SOCKET, $buffer, 1) == 1 or fatal "Error reading from win32 machine\n";
	
	my $clientsuccess = 0;
	$clientsuccess = 1 if($buffer eq SUCCESSFUL_TEST);
	
	writelog("Client success: $clientsuccess/1");
	return 0 if($clientsuccess != 1);
	
	return 1;
}

sub testBootleg
{
	print "Testing build...\n";
	writelog("Testing build");
	my $test = 0;

	startServer();
	startClient();
	
	$test = checkResponses();
	
	endServer();
	endClient();
	
	fatal "Test for build $newbootleg unsuccessful\n" if(!$test);
	print "Testing successful.\n\n";
	writelog("Test for build successful: $test");
	open(BLESS, ">$builddir/$branch/$newbootleg/blessed.txt");
	close(BLESS);
	
	return 1;
}

sub email
{
	# If we don't know the old bootleg (from install), get it
	if($oldbootleg eq "")
	{
		my @bootlegs;
		
		opendir DH, "$builddir/$branch" or fatal "Cannot open $builddir/$branch: $!\n";
		foreach (readdir DH)
		{
			push @bootlegs, $_ if(/^\d+$/ && -d ("$builddir/$branch/$_"));
		}
		closedir DH;	
		
		foreach (sort {$b <=> $a} @bootlegs)
		{
			if(-e "$builddir/$branch/$_/blessed.txt")
			{
				# This is the first blessed bootleg
				$newbootleg = $_ if($newbootleg eq "");
				
				# This is the second blessed bootleg
				$oldbootleg = $_ if($newbootleg ne $_);
			}
			last if($oldbootleg ne "");
		}		
	}
	
	print "Emailing about changes from bootleg $oldbootleg to $newbootleg...\n";
	writelog("Emailing changes from $oldbootleg to $newbootleg");
	return 0 if($oldbootleg eq "");
	open(EMAIL, "| mail -s \"[bootleg] $branch.$newbootleg.0 is up\" $emailRecipients");
	
	print EMAIL "${builddir}/\n".
	    "\n-Vijay\n\n";
	
	print EMAIL "Changes between $oldbootleg and $newbootleg\n";
	
	open(CHANGES, "perl ${depotdir}/swg/current/tools/BuildChanges.pl -i //depot/swg/$branch/... $oldbootleg $newbootleg |");
	while(<CHANGES>)
	{
		next if(/^Change (\d+) on/ || /^\[(public|internal)\]/ || /^\n/ || /.?none.?/i || /n(\/|\.)a/i || /^---/ || /ignoring script recompile/i);
		s/^\s*-?\s*//;
		print EMAIL "\t- $_";
	}
	close(CHANGES);
	print "Completed emailing.\n\n";
	writelog("Completed emailing.");
	
	return 1;
}

sub upkeep
{
	my $removedbootlegs = 0;

	print "Performing upkeep on bootleg directory for $branch...\n";
	writelog("Performing upkeep on bootleg directory for $branch...");
	
	my $controller = perforceWhere("//depot/swg/current/tools/build_cluster_controller.pl");
	my $buildcluster;
	
	open(BUILD, "perl $controller -bootleg-version 2>&1 |");
	while(<BUILD>)
	{
		$buildcluster = $1 if(/^Build cluster bootleg version is: (\d+)/);
	}		
	close(BUILD);
	
	return 0 if(!defined $buildcluster);

	my @bootlegs;
	opendir DH, "$builddir/$branch" or fatal "Cannot open $builddir/$branch: $!\n";
	foreach (readdir DH)
	{
		push @bootlegs, $_ if(/^\d+$/ && -d ("$builddir/$branch/$_"));
	}
	closedir DH;	
	
	@bootlegs = sort { $a <=> $b } @bootlegs; 
	
	while(@bootlegs > $numbootlegs)
	{
		my $bootleg = shift @bootlegs;
		next if($buildcluster == $bootleg);
		
		print STDERR "Removing bootleg $bootleg...\n";
		writelog("Removing bootleg $bootleg...");
		system("rm -fr $builddir/$branch/$branch/$bootleg");
		++$removedbootlegs;
	}
	
	print STDERR "Completed upkeep on bootleg directory - removed $removedbootlegs bootlegs.\n";
	writelog("Completed upkeep on bootleg directory - removed $removedbootlegs bootlegs.");
	
	return 1;
}

# ======================================================================
# Main
# ======================================================================

usage() if(!GetOptions('install' => \$steps[0], 'test' => \$steps[1], 'email' => \$steps[2], 'upkeep' => \$steps[3]));
usage() if(@ARGV != 1);

# open the log file
open(LOG, ">>$logfile");
unbuffer(\*LOG);

$branch = shift;
print "Beginning test for branch $branch\n";
writelog("Beginning test for branch $branch");

installBootleg() || fatal "installBootleg" if($steps[0]);
testBootleg() || fatal "testBootleg" if($steps[1]);
email() || fatal "email" if($steps[2]);
upkeep() || fatal "upkeep" if($steps[3]);

print "Test of $newbootleg complete.\n";
writelog("test of $newbootleg complete");

close(LOG);
