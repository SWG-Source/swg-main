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

my $depotdir = "/swg";
my $bootlegdir = "/swg/bootlegs";
my $logfile = "build_bootleg.log";
my $win32machine = "64.37.133.173";
my $port = "21498";
my $emailRecipients = "vthakkar\@soe.sony.com";

my $waittime = "180";
my $branch = "";
my $oldbootleg = "";
my $newbootleg = "";
my $loginpid;
my $taskpid;

my @steps = (0, 0, 0, 0, 0, 0, 0, 0);

# ======================================================================
# Subroutines
# ======================================================================

sub usage
{
	print "\n\t$name <optional parameters> <branch>\n\n".
		"\tOptional parameters:\n\n".
		"\t\t--no_script\t: Don't do a script recompile\n".
		"\t\t--no_build\t: Don't build a new bootleg\n".
		"\t\t--no_patch\t: Don't create a patchtree file\n".
		"\t\t--no_send\t: Don't send build / patch results to win32 machine\n".
		"\t\t--no_install\t: Don't install newest bootleg\n".
		"\t\t--no_test\t: Don't perform test on bootleg\n".
		"\t\t--no_email\t: Don't send email about results\n".
		"\t\t--no_upkeep\t: Don't perform upkeep on bootleg directories\n".
		"\n\tWarning: Some options depend on others, some combinations may not work.\n";
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

sub buildBootleg
{
	my $win32complete = 0;
	my $linuxcomplete = 0;
	
	print "Building bootleg...\n";
	writelog("Building bootleg");
	open(LINUXBUILD, "perl ${depotdir}/swg/current/tools/build_script_linux_new.pl $branch -bootleg -incrediBuild 2>&1 |") or fatal "Error running build_script_linux.pl\n";
	
	while(<LINUXBUILD>)
	{
		print;
		writelog($_);
		$newbootleg = $1 if(/^Syncing to $branch\@(\d+)/);
		$win32complete = 1 if(/^Windows build returned 0/);
		$linuxcomplete = 1 if(/^Linux build returned 0/);
	}
	
	close(LINUXBUILD);	
	
	print "linux build incomplete\n" if(!$linuxcomplete);
	print "windows build incomplete\n" if(!$win32complete);
	print "Completed building bootleg $newbootleg.\n\n" if($win32complete && $linuxcomplete);
	
	writelog("Bootleg: $newbootleg, Linux complete: $linuxcomplete, Windows complete: $win32complete");
	($win32complete && $linuxcomplete) ? return 1 : return 0;
}

sub buildPatchTree
{
	my $patch_tree_complete = 0;
	my $patch_changelist = 0;
	
	print "Building patch tree...\n";
	writelog("Building patch tree");
	mkdir "$bootlegdir/$branch/$newbootleg/patch" || fatal "mkdir for patchtree failed";
	
	open(PATCHTREE, "perl ${depotdir}/swg/current/tools/CheckPatchTreeSize.pl --sync --changelist=$newbootleg --save_treefile=$bootlegdir/$branch/$newbootleg/patch/bootlegpatch.tre |") or fatal "Error running CheckPatchTreeSize.pl\n";
	while(<PATCHTREE>)
	{
		print;
		writelog($_);
		$patch_changelist = $1 if(/^Most recent final manifest at revision \d+, patch \d+, changelist (\d+)/);
		$patch_tree_complete = 1 if(/^Size of \.tre is: \d+$/);
	}
	close(PATCHTREE);
	
	move "$bootlegdir/$branch/$newbootleg/patch/bootlegpatch.tre", "$bootlegdir/$branch/$newbootleg/patch/bootleg_${patch_changelist}_${newbootleg}.tre";
	
	print "Patch tree build incomplete.\n\n" if(!$patch_tree_complete);
	print "Patch tree build complete.\n\n" if($patch_tree_complete);
	
	writelog("Patch Tree complete: $patch_tree_complete");
	return $patch_tree_complete;
}

sub sendBootleg
{
	print "Sending bootleg / patch to win32 machine...\n";
	writelog("Sending bootleg / patch to win32 machine...");
	
	openClientSocket();
	
	print SOCKET START_BOOTLEG_SEND;
	print SOCKET pack("N", length $branch);
	print SOCKET $branch;	
	print SOCKET pack("N", $newbootleg);
	
	# Build an array of what directories to send over
	my @directories;
	push @directories, "patch" if(-d "$bootlegdir/$branch/$newbootleg/patch");
	push @directories, "servers" if(-d "$bootlegdir/$branch/$newbootleg/servers");
	
	while(@directories = sort @directories)
	{
	        my $dir = shift @directories;
	    
		# Tell the windows machine to get a new directory
		print SOCKET BOOTLEG_SEND_DIRECTORY;
		print SOCKET pack("N", length $dir);
		print SOCKET $dir;
	
		opendir DH, "$bootlegdir/$branch/$newbootleg/$dir" || die "could not open directory\n";
		foreach my $fileName (sort readdir DH)
		{
			next if($fileName eq "." || $fileName eq "..");
			push @directories, "$dir/$fileName" if(-d "$bootlegdir/$branch/$newbootleg/$dir/$fileName");
			next if(!-f "$bootlegdir/$branch/$newbootleg/$dir/$fileName");
			
			my $fileSize = -s "$bootlegdir/$branch/$newbootleg/$dir/$fileName";
			print "Sending file $fileName ($fileSize bytes)\n";
			writelog("Sending file $fileName ($fileSize bytes)");
			print SOCKET BOOTLEG_SEND_FILE;
			print SOCKET pack("NN", length $fileName, $fileSize);
			print SOCKET $fileName;
			open(F, "<$bootlegdir/$branch/$newbootleg/$dir/$fileName");
				binmode(F);
				while ($fileSize)
				{
					my $buffer;
					my $readSize = 16 * 1024;
					$readSize = $fileSize if ($fileSize < $readSize);
					my $readResult = read(F, $buffer, $readSize);
					die "unexpected end of file" if (!defined($readResult));
					die "did not read what we expected to" if ($readResult != $readSize);		
					print SOCKET $buffer;
					$fileSize -= $readResult;
				}
				die "copied all the bytes but not at EOF" if (!eof(F));		
			close(F);
		}
		closedir DH;
	}
	
	print SOCKET END_BOOTLEG_SEND;
	print "Finished sending to win32 machine.\n";
	writelog("Finished sending to win32 machine.");
	close(SOCKET);
		
	return 1;
}

sub installBootleg
{
	print "Installing bootleg...\n";
	writelog("Installing bootleg");

	open(INSTALL, "perl " . perforceWhere("//depot/swg/current/tools/InstallBootleg.pl") . " --list --force_newest --server_only --install_as_build_cluster $branch |") or fatal "Error running InstallBootleg.pl\n";
	
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
		last if(/^Log observer setup/);
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
	print "Testing bootleg...\n";
	writelog("Testing bootleg");
	my $test = 0;

	startServer();
	startClient();
	
	$test = checkResponses();
	
	endServer();
	endClient();
	
	fatal "Test for bootleg $newbootleg unsuccessful\n" if(!$test);
	print "Testing successful.\n\n";
	writelog("Test for bootleg successful: $test");
	open(BLESS, ">$bootlegdir/$branch/$newbootleg/blessed.txt");
	close(BLESS);
	
	return 1;
}

sub email
{
	return 0 if($newbootleg eq "");

        # Get old bootleg if we don't know it
        if($oldbootleg eq "")
	{
	        openClientSocket();
	    
		print SOCKET START_EMAIL;
		# Tell the client which bootleg to ignore
		print SOCKET pack("N", length $newbootleg);
		print SOCKET $newbootleg;

		my $buffer;
		return 0 if(read(SOCKET, $buffer, 4) != 4);
		my $oldBootlegLength = unpack("N", $buffer);
		return 0 if($oldBootlegLength == 0);
		return 0 if(read(SOCKET, $oldbootleg, $oldBootlegLength) != $oldBootlegLength);
		
		close(SOCKET);   
	}
	
	print "Emailing about changes from bootleg $oldbootleg to $newbootleg...\n";
	writelog("Emailing changes from $oldbootleg to $newbootleg");
	return 0 if($oldbootleg eq "");
	open(EMAIL, "| mail -s \"[bootleg] $branch.$newbootleg.0 is up\" $emailRecipients");
	
	print EMAIL "${bootlegdir}/\n".
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
	my $buffer;
	
	print "Performing upkeep on bootleg directory for $branch...\n";
	writelog("Performing upkeep on bootleg directory for $branch...");
	
	openClientSocket();
	
	print SOCKET START_UPKEEP;
	print SOCKET pack("N", length $branch);
	print SOCKET $branch;	

	return 0 if(read(SOCKET, $buffer, 1) != 1);

	if($buffer eq FAILED_GETTING_BUILD_CLUSTER_VERSION)
	{
		print "Failed getting build cluster version\n";
		writelog("Failed getting build cluster version");
		return 0;
	}
	elsif($buffer eq GOT_BUILD_CLUSTER_VERSION)
	{
		return 0 if(read(SOCKET, $buffer, 4) != 4);
		my $buildClusterBootleg = unpack("N", $buffer);
		print "Build cluster bootleg version is $buildClusterBootleg\n";
		writelog("Build cluster bootleg version is $buildClusterBootleg");
	}	
	else
	{
		print "Got incorrect return from win32 machine\n";
		writelog("Got incorrect return from win32 machine.");
		return 0;
	}
	
	while(1)
	{
		return 0 if(read(SOCKET, $buffer, 4) != 4);
		my $bootlegVer = unpack("N", $buffer);
		last if($bootlegVer == 0);
		print "Removed bootleg $branch/$bootlegVer.\n";
		writelog("Removed bootleg $branch/$bootlegVer.");
	}
	
	while(1)
	{
		return 0 if(read(SOCKET, $buffer, 4) != 4);
		my $pdbFileLength = unpack("N", $buffer);
		last if($pdbFileLength == 0);
		return 0 if(read(SOCKET, $buffer, $pdbFileLength) != $pdbFileLength);
		print "Removed pdb file $buffer.\n";
		writelog("Removed pdb file $buffer.");
	}	
	
	close(SOCKET);
}

sub submitOpenFiles
{
	local $_;
	my @files;
	open(P4, "p4 -ztag opened -c default |");

		while (<P4>)
		{
			chomp;
			push (@files, $_) if (s/^\.\.\. depotFile //);
		}

	close(P4);

	my $tmpfile = "submit.tmp";
	
	# submit all the open files
	open(TMP, ">" . $tmpfile);

		print TMP "Change:\tnew\n";
		print TMP "\nDescription:\n";

		foreach (@_)
		{
			print TMP "\t", $_, "\n";
		}
		
		print TMP "\nFiles:\n";
		foreach (@files)
		{
			print TMP "\t", $_, "\n";
		}

	close(TMP);

	my $result = system("p4 submit -i < $tmpfile");
	fatal "p4 submit failed" if ($result != 0);
	unlink($tmpfile);
}

sub scriptRecompile
{
	print "Recompiling scripts...\n";
	
	writelog("Syncing perforce for script recompile...");
	system("p4 sync //depot/swg/$branch/...") == 0 || return 0;
	writelog("Sync perforce complete.");
	writelog("Recompiling scripts...");
	
	my $result = system("perl ${depotdir}/swg/current/tools/recompileAllScripts.pl $branch");
	
	writelog("Recompile scripts returned $result (success = 0)");

	if ($result != 0)
	{
		my $attach = "";
		$attach .= " -a pythonPreprocessorStderr.log" if (-s "pythonPreprocessorStderr.log");
		$attach .= " -a javac.log" if (-s "javac.log");
		system("mutt -s \"[BUILDLOG $branch] script recompile failed, errors attached\" $attach $emailRecipients < /dev/null");
		system("p4 revert -c default //depot/... > /dev/null");
		return 0;
	}

	system("p4 revert -a > /dev/null");
	submitOpenFiles("[automated]", "Script recompile for bootleg build");
	
	print "Recompile scripts successful.\n";
	return 1;
}

# ======================================================================
# Main
# ======================================================================

usage() if(!GetOptions('no_script' => \$steps[0], 'no_build' => \$steps[1], 'no_patch' => \$steps[2], 'no_send' => \$steps[3], 'no_install' => \$steps[4], 'no_test' => \$steps[5], 'no_email' => \$steps[6], 'no_upkeep' => \$steps[7]));
usage() if(@ARGV != 1);

# open the log file
open(LOG, ">>$logfile") || die "Could not open $logfile\n";
unbuffer(\*LOG);

$branch = shift;
print "Beginning bootleg build for branch $branch\n";
writelog("Beginning bootleg build for branch $branch");

scriptRecompile() || fatal "scriptRecompile" if(!$steps[0]);
buildBootleg() || fatal "build" if(!$steps[1]);
buildPatchTree() || fatal "buildPatchTree" if(!$steps[2]);
sendBootleg() || fatal "sendBootleg" if(!$steps[3]);
installBootleg() || fatal "installBootleg" if(!$steps[4]);
testBootleg() || fatal "testBootleg" if(!$steps[5]);
email() || fatal "email" if(!$steps[6]);
upkeep() || fatal "upkeep" if(!$steps[7]);

print "Build of bootleg $newbootleg complete.\n";
writelog("Build of bootleg $newbootleg complete");

close(LOG);
