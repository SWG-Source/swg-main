#! /usr/bin/perl
# ======================================================================
# ======================================================================

use strict;
use warnings;
use Socket;
use File::Copy;

# ======================================================================
# Constants
# ======================================================================

use constant START_COMMUNICATION => "S";
use constant START_NOT_LOCKED_READY => "B";
use constant START_LOCKED_READY => "C";
use constant START_LOCKED_READY_UNAUTHORIZED_USER => "L";
use constant START_ERROR_AUTHORIZING => "K";

use constant END_COMMUNICATION => "E";
use constant END_SUCCESSFULL => "F";

use constant SUCCESSFULL_COMMAND => "P";
use constant FAILED_COMMAND => "U";
use constant UPDATE_BOOTLEG_STEP_OK => "G";
use constant UPDATE_BOOTLEG_STEP_FAILED => "H";
use constant UPDATE_BOOTLEG_SEND_DIRECTORY => "M";
use constant UPDATE_BOOTLEG_SEND_FILE => "N";
use constant UPDATE_BOOTLEG_FILES_FINISHED => "Q";
use constant SNAPSHOT_FAILED => "O";
use constant SNAPSHOT_SUCCESSFULL => "P";

use constant COMMAND_RESTART => "a";
use constant COMMAND_RESTART_LOGIN => "b";
use constant COMMAND_RESTART_NODES => "c";
use constant COMMAND_LOCK => "d";
use constant COMMAND_UNLOCK => "e";
use constant COMMAND_UPDATE_BOOTLEG => "f";
use constant COMMAND_CONTENT_SYNC => "g";
use constant COMMAND_SYNC_SPECIFIED_CHANGELISTS => "h";
use constant COMMAND_SNAPSHOT => "i";
use constant COMMAND_BOOTLEG_VERSION => "j";
use constant COMMAND_FREE_OBJECT_IDS => "k";

# ======================================================================
# Globals
# ======================================================================

my $buildCluster 	= "swo-dev9.station.sony.com";
my $port 		= "98452";
my $candela		= "p:";
my $exitcode		= 0;

my $name = $0;
$name =~ s/^(.*)\\//;

my $option;
my $command;
my $user;

# ======================================================================
# Subroutines
# ======================================================================

sub usage
{
	print STDERR "\nUsage:\n";
	print STDERR "\t$name [command(s)]\n\n".
		     "\t\t-restart :\n\t\t\t restart the build cluster (central node)\n".
		     "\t\t-restart-login :\n\t\t\t restart the Login server\n".
		     "\t\t-restart-nodes :\n\t\t\t restart all nodes of the build cluster\n".
		     "\t\t-lock :\n\t\t\t lock the build cluster (must be authorized user)\n".
		     "\t\t-unlock :\n\t\t\t unlock the build cluster (must be authorized user)\n".
		     "\t\t-update-bootleg <branch> :\n\t\t\t update the bootleg on the build cluster (p4 key check) - needs to be run in windows\n".
		     "\t\t-bootleg-version:\n\t\t\t check bootleg version on the build cluster\n".
		     "\t\t-free-object-ids :\n\t\t\t free object IDs in the database for the build cluster\n".
		     "\t\t-content-sync [changelist] :\n\t\t\t shut down, content sync to specific changelist (if none, content sync to head), bring up\n".
		     "\t\t-sync-specified-changelists <changelist [| changelist]> :\n\t\t\t shut down, sync to multiple specified changelists, bring up\n".
		     "\t\t-snap <schema> <branch> [dontsubmit] :\n\t\t\t free object IDs, make a snapshot, verifies before adding files to <branch> in perforce\n\t\t\t  and submits unless [dontsubmit]\n".
			 "\t\t\t If <schema> does not exist, it is created otherwise it is overwritten\n".
		     "\n\tIf multiple commands are given, the build cluster will go down / come up only once around the commands (if necessary)\n";
	die "\n";
}

sub exitFailed
{
	$exitcode = 1;
	goto FAIL;
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

sub checkarguments()
{
	my @args = @ARGV;

	while(@args)
	{
		my $elem = shift @args;

		# check if the key is valid if the command requires one
		if($elem =~ /^-snap$/)
		{
			$elem = shift @args;
			&usage() if(!(defined $elem) || $elem =~ /^-/);
			$elem = shift @args;
			&usage() if(!(defined $elem) || $elem =~ /^-/);			
			# check for optional parameter
			shift @args if((defined $args[0]) && $args[0] eq "dontsubmit");
		}
		elsif($elem =~ /^-update-bootleg$/)
		{
			$elem = shift @args;
			&usage() if(!(defined $elem) || $elem =~ /^-/);
		}
		elsif($elem =~ /^-content-sync$/)
		{
			shift @args if(@args && !($args[0] =~ /^-/));
		}
		elsif($elem =~ /^-sync-specified-changelists$/)
		{
			$elem = shift @args;
			&usage() if(!defined $elem || $elem =~ /^-/);
			while(@args)
			{
				last if($args[0] =~ /^-/);
				shift @args;
			}
		}
		elsif(!($elem =~ /^-restart$/ || $elem =~ /^-restart-login$/ || $elem =~ /^-restart-nodes$/ || $elem =~ /^-lock$/ || $elem =~ /^-unlock$/ || $elem =~ /^-bootleg-version$/ || $elem =~ /^-free-object-ids$/ || $elem =~ /^-build_script_publish$/))
		{
			&usage();
		}
	}
}

sub openbuildsocket
{
	socket(BUILD, PF_INET, SOCK_STREAM, getprotobyname('tcp')) || die "socket failed\n";
	{
		my $destination = inet_aton($buildCluster) || die "inet_aton failed\n";
		my $paddr = sockaddr_in($port, $destination);
		connect(BUILD, $paddr) || die "connect failed\n";

		# unbuffer the socket
		my $oldSelect = select(BUILD);
		$| = 1;
		select($oldSelect);

		# put the socket into binary mode
		binmode BUILD;
	}
}

sub getuser
{
	my $user;
	
	open(P4, "p4 user -o |") || die "p4 user failed\n";
	while(<P4>)
	{
		$user = $1 if(/^User:\s+(\S+)/);
	}
	close(P4);
	
	die "Could not get perforce user\n" if(!defined $user);
	
	return $user;
}

sub sendstartinfo
{	
	print STDERR "Contacting build cluster...\n";
	print BUILD START_COMMUNICATION;
	
	my $initializer = $user;
	$initializer = "buildscript" if($user eq "build_script_publish");

	my $length = length $initializer;
	
	print BUILD pack("N", $length);
	print BUILD $initializer;

	my $returncode;
	if(read(BUILD, $returncode, 1) != 1)
	{
		print STDERR "Problem contacting build server\n";
		return 0;
	}
	
	if($returncode eq START_NOT_LOCKED_READY)
	{
		print STDERR "Build server is not locked and ready\n\n";
		return 1;
	}
	elsif($returncode eq START_LOCKED_READY)
	{
		print STDERR "Build server is locked and ready\n\n";
		return 1;
	}
	elsif($returncode eq START_LOCKED_READY_UNAUTHORIZED_USER)
	{
		print STDERR "Build server is locked (limited access for non-authoritative user)\n\n";
		return 1;
	}
	elsif($returncode eq START_ERROR_AUTHORIZING)
	{
		print STDERR "problem authorizing $user for build server\n\n";
		return 0;
	}
	else
	{
		print STDERR "Build server not ready\n\n";
		return 0;
	}
	
}

sub sendendinfo
{
	print STDERR "Ending communication with build cluster...\n";
	print BUILD END_COMMUNICATION;
	
	my $returncode;
	my $readreturn = read(BUILD, $returncode, 1);
	if(!defined $readreturn || $readreturn != 1)
	{
		print STDERR "Build server communication ended abruptly\n";
		return 0;
	}
	
	if($returncode eq END_SUCCESSFULL)
	{
		print STDERR "Build server communication ended successfully\n";
		return 1;
	}
	else
	{
		print STDERR "Build server communication ended with errors\n";
		return 0;
	}

}

sub contentsync
{
	my $changelist = "";

	$changelist = shift @ARGV if(@ARGV && !($ARGV[0] =~ /^-/));
	
	my $length = length $changelist;
		
	print BUILD pack("N", $length);
	print BUILD $changelist;
	
	# Recieve any errors from the content sync
	my $buffer;
	return 0 if(read(BUILD, $buffer, 4) != 4);
	$length = unpack("N", $buffer);
	return 0 if(read(BUILD, $buffer, $length) != $length);
	print $buffer;
	
	return 1;
}

sub syncspecifiedchangelists
{
	my $changelists = "";
	
	while(@ARGV)
	{
		last if($ARGV[0] =~ /^-/);

		my $elem = shift @ARGV;
		$changelists .= "$elem ";
	}
	
	chomp $changelists;
	
	if($changelists eq "")
	{
		print BUILD pack("N", 0);
		print STDERR "You must specify changelist\(s\)\n";
		return 0;
	}	
	
	my $length = length $changelists;
	
	print BUILD pack("N", $length);
	print BUILD $changelists;
	
	return 1;
}

sub endsubmit
{
	print "Error running: $_[0]\n";
	return 0;
}

sub submitopenfiles
{
	my $dontsubmit = shift;
	local $_;
	my @files;

	system("p4 revert -a > /dev/null");
	
	open(P4, "p4 -ztag opened -c default |");

		while (<P4>)
		{
			chomp;
			push (@files, $_) if (s/^\.\.\. depotFile //);
		}

	close(P4);

	if(!@files)
	{
		print STDERR "No changed files, nothing to submit\n";
		return 1;
	}

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

	if ($dontsubmit)
	{
		open(P4, "p4 change -i < $tmpfile |") || return 0;
		while(<P4>)
		{
			print STDERR "Successfully created changelist $1\n" if(/Change (\d+) created/);
		}
		close(P4);
	}
	else
	{
		open(P4, "p4 submit -i < $tmpfile |") || return 0;
		while(<P4>)
		{
			print STDERR "Successfully submitted at changelist $1\n" if(/Change (\d+) submitted/);
		}
		close(P4);
	}

	return 0 if ($? != 0);
	unlink($tmpfile);
	return 1;
}

sub snapshot
{
	my $dbSchema = shift @ARGV;
	my $branch = shift @ARGV;
	my $dontsubmit = 0;
	my $snapshotLog = "";
	my $buffer = "";
	my $p4operation = "submit";

	if (defined($ARGV[0]) && $ARGV[0] eq "dontsubmit")
	{
		$dontsubmit = 1;
		$p4operation = "change";
		shift @ARGV;
	}

	print BUILD pack("N", length $dbSchema);
	print BUILD $dbSchema;
	
	if(read(BUILD, $buffer, 1) != 1 || $buffer eq SNAPSHOT_FAILED)
	{
		print STDERR "Snapshot not created successfully on the build cluster\n";
		return 0;
	}
	
	# Recieve files
	my @worldSnapshots;
	
	print STDERR "Snapshot generation complete.\n";
	while(1)
	{
		return 0 if (read(BUILD, $buffer, 2*4) != 2*4);
		my ($fileSize, $fileNameLength) = unpack("NN", $buffer);

		# check if we are finished
		last if($fileSize == 0 && $fileNameLength == 0);

		my $localFileName;
		return 0 if (read(BUILD, $localFileName, $fileNameLength) != $fileNameLength);

		# first file sent will be the snapshot log
		$snapshotLog = $localFileName if($snapshotLog eq ""); 

		# add all ws files to the array
		push @worldSnapshots, $localFileName if($localFileName =~ /\.ws$/);

		# receive the binary bits for the file		
		print STDERR "Receiving $localFileName ($fileSize bytes)...";
		unlink $localFileName;
		open(F, ">" . $localFileName) || return endbootleginstall("could not open $localFileName for writing");
			binmode(F);
			while ($fileSize)
			{
				my $readSize = 16 * 1024;
				$readSize = $fileSize if ($fileSize < $readSize);
				my $readResult = read(BUILD, $buffer, $readSize);
				return 0 if (!defined($readResult));
				return 0 if ($readResult == 0);
				print F $buffer;
				$fileSize -= $readResult;
			}
		return 0 if ($fileSize != 0);		
		close(F);
		print "done\n";
	}	

	# Echo log to user	
	print STDERR "--- Start of snapshot log:\n";
	system("cat $snapshotLog") == 0 || return 0;
	print STDERR "--- End of snapshot log:\n";
	
	# Only verify using STDIN if we are not being called by the build script
	if($user ne "build_script_publish")
	{
		print STDERR "\nAre the world snapshots ok to do perforce $p4operation? (y/n)\n";
		while(<STDIN>)
		{
			chomp;

			if($_ eq "y" || $_ eq "Y")
			{
				last;
			}
			elsif($_ eq "n" || $_ eq "N")
			{
				return 1;
			}
			print STDERR "Please enter \'y\' or \'n\'\n";
		}
	}

	# If we get here, we have decided to submit
	print STDERR "Proceeding with $p4operation\n";
	
	# Get a hash of the current world snapshots in perforce
	my %ws;
	open(FILES, "p4 files //depot/swg/$branch/data/sku.0/sys.client/built/game/snapshot/... |") || return endsubmit("p4 files");
	while(<FILES>)
	{
		$ws{$1} = 1 if(/\/([^\/]+\.ws)#/);
	}
	close(FILES);
	
	# Edit files and move to appropriate directory
	system("p4 edit //depot/swg/$branch/data/sku.0/sys.client/built/game/snapshot/...") == 0 || return endsubmit("p4 edit snapshot dir");
	
	foreach(@worldSnapshots)
	{
		system("p4 add //depot/swg/$branch/data/sku.0/sys.client/built/game/snapshot/$_") == 0 || return endsubmit("p4 add") if(!exists($ws{$_}));
		copy($_, perforceWhere("//depot/swg/$branch/data/sku.0/sys.client/built/game/snapshot/$_")) || return endsubmit("moving *.ws to snapshot dir");
	}
	
	system("p4 edit //depot/swg/$branch/dsrc/sku.0/sys.client/built/game/snapshot/swg_object.txt") == 0 || return endsubmit("p4 edit swg_object.txt");
	copy("swg_object.txt", perforceWhere("//depot/swg/$branch/dsrc/sku.0/sys.client/built/game/snapshot/swg_object.txt")) || return endsubmit("moving object file to swg_object.txt");
	
	# create golddata text file
	createGoldDataFile($dbSchema, $branch);
	
	submitopenfiles($dontsubmit, "[automated]", "New snapshots for $branch from build_cluster_controller ($dbSchema)") || return endsubmit("p4 $p4operation");
	
	return 1;
}

sub createGoldDataFile
{
	my ($dbSchema, $branch) = @_;
	my $goldDataFile = perforceWhere("//depot/swg/$branch/src/game/server/database/build/linux/golddata.txt");

	system("p4 edit $goldDataFile");

	open(GOLDDATA, "> $goldDataFile");
	print GOLDDATA "$dbSchema\n";
	close GOLDDATA;

	system("p4 add $goldDataFile");
}

sub getbootlegversion
{
	my $buffer;
	return 0 if(read(BUILD, $buffer, 4) != 4);
	my $length = unpack("N", $buffer);
	return 0 if(read(BUILD, $buffer, $length) != $length);
	
	if($length == 0)
	{
		print STDERR "Could not get build cluster bootleg version\n";
		return 0;
	}
	
	print STDERR "Build cluster bootleg version is: $buffer\n";
	return 1;	
}

sub updatebootleg
{
	my $branch = shift @ARGV;

	# Get the number of the most recent bootleg
	my $dir = "$candela/swo/builds/$branch";
	
	my $buffer;
	my $change = 0;
	opendir DH, $dir or return 0;
	foreach (readdir DH)
	{
		$change = $_ if(/^\d+$/ && -d ($dir."/".$_) && $_ > $change);
	}
	closedir DH;
	return 0 if(!$change);
	
	print STDERR "Most recent blessed bootleg is: $change\n";
		
	# Send info to build cluster
	print STDERR "Syncing build cluster to $change...\n";
	print BUILD pack("N", $change);	
	return 0 if(read(BUILD, $buffer, 1) != 1 || $buffer ne UPDATE_BOOTLEG_STEP_OK);
	print STDERR "Sync of build cluster complete.\n";

	# Compress the server binaries
	my $file = "servers_debug.tar.gz";

	print STDERR "Compressing server binaries...\n";
	system("tar --create --gzip --directory=$dir/$change/servers_debug --file=/tmp/$file .") == 0 || die "Failed to compress $dir/$change/servers_debug";
	print STDERR "Compress server binaries complete.\n";
	
	# Send file to build cluster
	die "Can't find server zip file!\n" if (!-s "c:/cygwin/tmp/$file");
	my $fileSize = -s "c:/cygwin/tmp/$file";
	print STDERR "Sending file $file ($fileSize bytes)\n";
	print BUILD pack("NN", $fileSize, length $file);
	print BUILD $file;
	open(F, "<c:/cygwin/tmp/$file");
		binmode(F);
		while ($fileSize)
		{
			my $buffer;
			my $readSize = 16 * 1024;
			$readSize = $fileSize if ($fileSize < $readSize);
			my $readResult = read(F, $buffer, $readSize);
			die "unexpected end of file" if (!defined($readResult));
			die "did not read what we expected to" if ($readResult != $readSize);		
			print BUILD $buffer;
			$fileSize -= $readResult;
		}
		die "copied all the bytes but not at EOF" if (!eof(F));		
	close(F);

	# Cleanup
	unlink "c:/cygwin/tmp/$file";

	if(read(BUILD, $buffer, 1) != 1 || $buffer ne UPDATE_BOOTLEG_STEP_OK)
	{
		print "Failed while sending file.\n";
		closedir DH;
		return 0;
	}
	print "$file sent.\n";
	
	print STDERR "Updating database on build cluster...\n";
	return 0 if(read(BUILD, $buffer, 1) != 1 || $buffer ne UPDATE_BOOTLEG_STEP_OK);
	print STDERR "Database update on build cluster complete.\n";
	
	print STDERR "Syncing individual changelists on build cluster...\n";
	my @syncChangelists;
	open(SYNC, "$candela/SWO/builds/$branch/$change/sync.txt") || return 0;
	while(<SYNC>)
	{
		chomp;
		push @syncChangelists, $_;		
	}
	close(SYNC);
	print BUILD pack("N", length (join(" ", @syncChangelists)));
	print BUILD join(" ", @syncChangelists);
	return 0 if(read(BUILD, $buffer, 1) != 1 || $buffer ne UPDATE_BOOTLEG_STEP_OK);
	print STDERR "Inidividual changelist sync complete.\n";
	
	return 1;
	
}

# ======================================================================
# Main
# ======================================================================

&usage if(@ARGV == 0);

# Check to see if we're testing
if($ARGV[0] eq "vthakkar-box")
{
	shift;
	$buildCluster = "lin-vthakkar.station.sony.com";
}

$user = getuser();
$user = "build_script_publish" if(grep("-build_script_publish" eq $_, @ARGV));

checkarguments();

openbuildsocket();

sendstartinfo() || exitFailed();

while(@ARGV)
{

	$option = shift @ARGV;
	
	if($option eq "-restart")
	{
		print STDERR "Restarting build cluster...\n";
		print BUILD COMMAND_RESTART;
	}
	elsif($option eq "-restart-login")
	{
		print STDERR "Restarting loginserver on build cluster...\n";
		print BUILD COMMAND_RESTART_LOGIN;
	}
	elsif($option eq "-restart-nodes")
	{
		print STDERR "Restarting build cluster nodes...\n";
		print BUILD COMMAND_RESTART_NODES;
	}
	elsif($option eq "-lock")
	{
		print STDERR "Locking build cluster...\n";
		print BUILD COMMAND_LOCK;
	}
	elsif($option eq "-unlock")
	{
		print STDERR "Unlocking build cluster...\n";
		print BUILD COMMAND_UNLOCK;
	}
	elsif($option eq "-update-bootleg")
	{
		print STDERR "Updating bootleg on build cluster...\n";
		print BUILD COMMAND_UPDATE_BOOTLEG;
		updatebootleg() || goto ERROR;
	}
	elsif($option eq "-content-sync")
	{
		print STDERR "Content syncing build cluster...\n";
		print BUILD COMMAND_CONTENT_SYNC;
		contentsync() || goto ERROR;
	}
	elsif($option eq "-sync-specified-changelists")
	{
		print STDERR "Syncing build cluster to changelists...\n";
		print BUILD COMMAND_SYNC_SPECIFIED_CHANGELISTS;
		syncspecifiedchangelists() || goto ERROR;
	}
	elsif($option eq "-snap")
	{
		print STDERR "Creating snapshot on build cluster...\n";
		print BUILD COMMAND_SNAPSHOT;
		snapshot() || goto ERROR;
	}
	elsif($option eq "-bootleg-version")
	{
		print STDERR "Checking bootleg version on build cluster...\n";
		print BUILD COMMAND_BOOTLEG_VERSION;
		getbootlegversion() || goto ERROR;
	}
	elsif($option eq "-free-object-ids")
	{
		print STDERR "Freeing object ids on build cluster...\n";
		print BUILD COMMAND_FREE_OBJECT_IDS;
	}
	elsif($option eq "-build_script_publish")
	{
		next;
	}
	else
	{
		print STDERR "Error: cannot decipher option: $option\n";
		goto FAIL;
	}
	
ERROR:
	my $success;
	exitFailed() if(!read(BUILD, $success, 1));	
	if($success eq SUCCESSFULL_COMMAND)
	{
		print STDERR "Successfully completed $option\n\n";
	}
	else
	{
		print STDERR "Error encountered while running $option\n\n";
		exitFailed();
	}
	
}

FAIL:
sendendinfo();

close(BUILD);

exit($exitcode);
