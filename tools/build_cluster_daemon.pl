#! /usr/bin/perl

use warnings;
use strict;
use Socket;
use POSIX qw(setsid);

# ======================================================================
# notes
# add serverop user
# remove dsrc from build cluster
# ======================================================================

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
use constant UPDATE_BOOTLEG_FILES_FINISHED => "Q";
use constant UPDATE_BOOTLEG_SEND_FILE => "N";
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

my $p4 = "/usr/local/bin/p4";
my $port = '98452';
my $snapShotOutputFile = "/tmp/swg_object.txt";
my $logfile = "build_cluster.log";
my $depotdir = "/swo/";
my $branch;

my @authorizedUsers =
(
    "buildscript",
    "gmcdaniel",
    "ttyson",
    "tcramer",
    "sthomas"
);

my $user = "none";
my $keyuser = "none";
my $serverdown = 0;
my $email = 0;
my %nodes;

my $name = $0;
$name =~ s/^(.*)\\//;

# Access level:
# 0 - Cluster is locked and incorrect user is trying to access
# 1 - Cluster is unlocked
# 2 - Cluster is locked and user is valid
my $accesslevel = 0;

$ENV{"P4PORT"}   = "aus-perforce1.station.sony.com:1666";
$ENV{"P4CLIENT"} = "serverop-swo-dev9";

# ======================================================================
# Subroutines
# ======================================================================

sub usage
{
    print STDERR "\nUsage:\n";
    print STDERR "\t$name branch [-d <log file directory>]\n\n".
        "\t\tbranch : required perforce branch name (e.g. current or s7)\n".
        "\t\t-d     : daemonize script (e.g. -d /tmp/)\n";
    die "\n";
}

sub prompt
{
    print $_[0], "\n";

    do
    {
        #print "Continue (y/n): ";
        $_ = "y"; # <STDIN>;
        return if (/^y/i);
        die "Aborting\n" if (/^n/i);
    } while (1);
}

sub asksystem
{
    print "Execute: $_[0]\n";
    do
    {
        #print "(y/n/A): ";
        $_ = "y"; # <STDIN>;
        return system($_[0]) if (/^y/i);
        return 0 if (/^n/i);
        die "Aborting\n" if (/^A/);
    } while (1);
}

sub endFunc
{
    writelog("Failed while running: $_[0]");
    print STDERR "Failed while running: $_[0]\n";
    return 0;
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

sub writelog
{
    my $message = shift @_;
    my ($sec, $min, $hr, $day, $mon, $yr) = localtime time;
    my $timestamp = sprintf "%4s-%02s-%02s\t%02s:%02s:%02s", ($yr + 1900), ($mon + 1), $day, $hr, $min, $sec;
    my $lock = locked() ? "locked" : "unlocked";

    print LOG join("\t", $timestamp, $user, $lock, $message), "\n";
}

sub initcommunication
{
    my $buffer;

    $user = "none";
    $keyuser = "none";
    $accesslevel = 0;

    return endFunc("Did not recieve enough bytes from socket (!= 4)") if (read(SOCKET, $buffer, 4) != 4);

    my $length = unpack("N", $buffer);

    return endFunc("Did not recieve enough bytes from socket (!= $length)") if(read(SOCKET, $buffer, $length) != $length);

    if($buffer eq "buildscript")
    {
        writelog("Build script - bypassing key check");
        $accesslevel = 2;
        $user = "build_script";
        print SOCKET START_LOCKED_READY;
        return 1;
    }

    $user = $buffer;
    my $isValidUser = grep($user eq $_, @authorizedUsers);

    if(!locked())
    {
        # Cluster is unlocked
        $accesslevel = ($isValidUser == 0) ? 1 : 2;
        writelog("Communication initialized");
        print SOCKET START_NOT_LOCKED_READY;
        return 1;
    }
    elsif(!$isValidUser)
    {
        # Cluster is locked, and the and an unauthorized user is accessing
        $accesslevel = 0;
        writelog("Build locked and unauthorized user accessing");
        print SOCKET START_LOCKED_READY_UNAUTHORIZED_USER;
        return 1;
    }
    else
    {
        # Cluster is locked, and the user is valid
        $accesslevel = 2;
        writelog("Communication initialized");
        print SOCKET START_LOCKED_READY;
        return 1;
    }
}

sub endcommunication
{
    if(bringup() == 0)
    {
        writelog("Error bringing cluster back up");
        print SOCKET FAILED_COMMAND;
        return 0;
    }

    print STDERR "Communication ended\n";
    writelog("Communication ended");
    print SOCKET END_SUCCESSFULL;

    $user = "none";
    $keyuser = "none";
    $accesslevel = 0;

    return 1;
}

sub lockcluster
{
    if($accesslevel == 2)
    {
        print STDERR "Locking build cluster...\n";
        asksystem("p4 counter swg-$branch-build-lockout 1");
        return 1;
    }
    else
    {
        print STDERR "Not authorized to lock build cluster...\n";
        return 0;
    }
}

sub unlockcluster
{
    if($accesslevel == 2)
    {
        print STDERR "Unlocking build cluster...\n";
        asksystem("p4 counter swg-$branch-build-lockout 0");
        return 1;
    }
    else
    {
        print STDERR "Not authorized to unlock build cluster...\n";
        return 0;
    }

}

sub locked
{
    my $lock = `$p4 counter swg-$branch-build-lockout`;
    chomp $lock;
    return $lock;
}

sub bringdown
{
    if($serverdown == 0)
    {
        system("mail -s \"[BUILDCLUSTER] Build cluster coming down for a $_[0]\" swo\@soe.sony.com < /dev/null") == 0 || return endFunc("send email") if($email);

        # stop the build cluster
        print STDERR "Bringing down the build cluster...\n";
        writelog("Bringing down the build cluster...");
        chdir("${depotdir}swg/$branch/exe/linux") || return endFunc("chdir");
        asksystem("./stopserver");
        $serverdown = 1;
    }
    return 1;
}

sub bringup
{
    if($serverdown == 1)
    {
        system("mail -s \"[BUILDCLUSTER] Build cluster coming back up\" swo\@soe.sony.com < /dev/null") == 0 || return endFunc("send email") if($email);

        # bring the build cluster up normally
        print STDERR "Bringing up the build cluster for $branch...\n";
        writelog("Bringing up the build cluster for $branch...");
        chdir("${depotdir}swg/$branch/exe/linux") || return endFunc("Cannot change to ${depotdir}swg/$branch/exe/linux - $!");
        asksystem("echo start | debug/TaskManager -- \@buildTaskManager.cfg 2>&1 | tee taskManager.log &");
        $serverdown = 0;
    }
    return 1;
}

sub restart
{
    return endFunc("Incorrect access level - need > 0") if ($accesslevel < 1);

    bringdown("restart") || errorcode("bringdown");
    bringup() || errorcode("bringup");

    return 1;
}

sub restartlogin
{
    return endFunc("Incorrect access level - need > 0") if ($accesslevel < 1);

    bringdown("restart login") || errorcode("bringdown");

    writelog("Bringing down LoginServer");
    asksystem("killall -9 LoginServer");

    asksystem("echo start | debug/LoginServer -- \@loginServer_buildCluster.cfg 2>&1 | tee loginServer.log &") == 0 || return endFunc("start LoginServer");

    return 1;
}

sub refreshnodes
{
    writelog("Refreshing the list of nodes");
    %nodes = ();

    open(LOCAL, "/swg/swg/$branch/exe/linux/localOptions.cfg") || return endFunc("error opening localOptions.cfg");
    while(<LOCAL>)
    {
        # Refresh all nodes, ignoring the head node
        $nodes{$1} = $2 if(/^node(\d+)=(\S+)/ && $1 != 0);
    }
    close(LOCAL);

    writelog("Completed refreshing the list of nodes");
}

sub bringnodesdown
{
    return endFunc("Incorrect access level - need > 0") if ($accesslevel < 1);

    writelog("Bringing down all nodes");
    my $remotecmd = "killall TaskManager";

    foreach my $node (sort keys %nodes)
    {
        writelog("Bringing down $nodes{$node}");
        my $result = system("ssh -f serverop\@$nodes{$node} \"$remotecmd \"");

        writelog("Error bringing down node $nodes{$node}") if($result != 0);
        }

    return 1;
}

sub bringnodesup
{
    return endFunc("Incorrect access level - need > 0") if ($accesslevel < 1);

    writelog("Bringing up all nodes");
    my $remotecmd = "ulimit -c unlimited; cd /swo/swg/$branch/exe/linux; debug/TaskManager -- \@remote_taskmanager.cfg";

    foreach my $node (sort keys %nodes)
    {
        writelog("Bringing up $nodes{$node}");
        my $result = system("ssh -f serverop\@$nodes{$node} \"$remotecmd 2>&1 \" > logs/taskmanager-$nodes{$node}.log");

        writelog("Error bringing up node $nodes{$node}") if($result != 0);
        }

    return 1;
}

sub restartnodes
{
    return endFunc("Incorrect access level - need > 0") if ($accesslevel < 1);

    refreshnodes() || errorcode("refreshnodelist");
    bringnodesdown() || errorcode("bringnodesdown");
    bringnodesup() || errorcode("bringnodesup");

    return 1;
}

sub endcontentsync
{
    print SOCKET pack("N", 0);
    return endFunc($_[0]);
}

sub runcontentsync
{
    my ($change) = @_;

    my $counter = `p4 counter swg-$branch-build-contentsync`;
    chomp $counter;

    return endFunc("Cannot content sync before $branch counter ($change < $counter)") if($change < $counter);

    my $messageToController = "";
    writelog("Content syncing from $counter to $change");

    # Fix for a Malformed UTF-8 error in perl 5.8.0
    my $oldLang;
    if(exists $ENV{"LANG"})
    {
        $oldLang = $ENV{"LANG"};
        $ENV{"LANG"} = "en_US";
    }

    open(CONTENTSYNC, "perl ${depotdir}swg/$branch/tools/ContentSync.pl 1 $branch $counter $change 2>&1 | ") || return endFunc("cannot open perl ContentSync.pl");
    while(<CONTENTSYNC>)
    {
        if(/^could not determine content status of /)
        {
            $messageToController .= $_;
            print STDERR $_;
            chomp;
            writelog($_);
        }
    }
    close(CONTENTSYNC);

    $ENV{"LANG"} = $oldLang if(defined $oldLang);

    print SOCKET pack("N", length $messageToController);
    print SOCKET $messageToController;

    $change = $1 if($messageToController =~ /^could not determine content status of \S+ for changelist (\d+)/);

    asksystem("p4 counter swg-$branch-build-contentsync $change") == 0 || return endFunc("Can't set counter swg-$branch-build-contentsync");

    return 1;
}


sub contentsync
{
    return endcontentsync("Incorrect access level - need > 0") if($accesslevel < 1);

    bringdown("content sync") || return endcontentsync("bringdown");

    # issue the content sync
    print STDERR "Content syncing...\n";
    chdir("${depotdir}swg/$branch/exe/linux") || endcontentsync("chdir");

    my $buffer;
    return endcontentsync("Did not recieve enough bytes from socket (!= 4)") if (read(SOCKET, $buffer, 4) != 4);

    my $length = unpack("N", $buffer);
    my $end;

    if($length != 0)
    {
        return endcontentsync("Did not recieve enough bytes from socket (!= $length)") if(read(SOCKET, $end, $length) != $length);
    }
    else
    {
        $end = `p4 counter change`;
        chomp $end;
    }

    runcontentsync($end) || return endcontentsync("runcontentsync");

    return 1;
}

sub changelistsync
{
    return endFunc("Incorrect access level - need > 0") if($accesslevel < 1);

    bringdown("changelist sync") || errorcode("bringdown");

    print STDERR "Syncing to changelists...\n";
    my $buffer;

    return endFunc("Did not recieve enough bytes from socket (!= 4)") if (read(SOCKET, $buffer, 4) != 4);

    my $length = unpack("N", $buffer);

    return endFunc("No changelists given") if ($length == 0);

    return endFunc("Did not recieve enough bytes from socket (!= $length)") if (read(SOCKET, $buffer, $length) != $length);

    my @cl = split / /, $buffer;

    my $counter = `p4 counter swg-$branch-build-contentsync`;
    chomp $counter;

    foreach (sort { $a <=> $b } @cl)
    {
        if($_ >= $counter)
        {
            writelog("Syncing to individual changelist $_");
            asksystem("$p4 sync //depot/swg/$branch/...\@$_,\@$_ > /dev/null 2>/dev/null") == 0 || return endFunc("Cannot sync //depot/swg/$branch/...\@$_,$_");
        }
        else
        {
            return endFunc("Cannot sync to a changelist less than contentsync ($_ < $counter)");
        }
    }

    return 1;
}

sub endsnap
{
    print SOCKET SNAPSHOT_FAILED;
    return 0;
}

sub makesnap
{
    bringdown("snapshot") || errorcode("bringdown");

    # get the name of the db schema to update
    my $buffer;
    my $dbSchema;
    return endsnap("Did not recieve enough bytes from socket (!= 4)") if (read(SOCKET, $buffer, 4) != 4);
    my $length = unpack("N", $buffer);
    return endFunc("Did not recieve enough bytes from socket (!= $length)") if (read(SOCKET, $dbSchema, $length) != $length);

    # create the gold schema user if not already created
    createuser($dbSchema);

    # bring the build cluster up with preloading
    writelog("Bringing up the build cluster in preload mode");
    print STDERR "Bringing up the build cluster in preload mode...\n";
    prompt("unlinking localOptions.cfg");
    unlink("localOptions.cfg");
    prompt("symlinking localOptions.cfg to snapshotLocalOptions");
    symlink("snapshotLocalOptions.cfg", "localOptions.cfg") || return endsnap();
    prompt("bringing up the build cluster");
    my $result = system("echo start | debug/TaskManager -- \@buildTaskManagerPublishMode.cfg 2>&1 | tee taskManager.log");

    # restore the normal config file
    writelog("Restoring the build cluster to normal mode");
    prompt("unlinking localOptions.cfg");
    unlink("localOptions.cfg");
    prompt("linking localOptions.cfg to normalLocalOptions.cfg");
    symlink("normalLocalOptions.cfg", "localOptions.cfg") || return endsnap();

    # handle the cluster startup failing
    # return endsnap() if ($result != 0);

    # copy to the publish cluster
    writelog("Copying to the publish database");
    print STDERR "Copying to the publish database...\n";
    chdir("${depotdir}swg/$branch/src/game/server/database/build/linux") || return endsnap();

    my $copyBuildClusterLog = "${depotdir}swg/$branch/src/game/server/database/build/linux/copy_buildcluster.log";
    my $copyComplete = 0;
    $buffer = "";
    unlink($copyBuildClusterLog);
    open(DBLOG, "perl copy_buildcluster.pl --copybuildcluster --username=$dbSchema 2>&1 |") || return endsnap();
    while(<DBLOG>)
    {
        $buffer .= $_;
        $copyComplete = 1 if(/^Import terminated successfully/); # Note: ^IMP- and ^EXP- and ^ORA- warnings during import are normal operation
    }
    close(DBLOG);
    my $copyReturn = $?;

    open (DBLOG, ">$copyBuildClusterLog");
    print DBLOG $buffer;
    close (DBLOG);

    if ($copyReturn != 0 || $copyComplete == 0)
    {
        print STDERR "failed to copy the build cluster - output is in $copyBuildClusterLog\n";
        writelog("failed to copy the build cluster - output is in $copyBuildClusterLog");
        return endsnap();
    }

    # Set the golddata schema name in the version_number table
    updateversion($dbSchema);

    # execute the snapshot query
    writelog("Executing the world snapshot query");
    print STDERR "Executing the world snapshot query...\n";
    unlink($snapShotOutputFile);
    chdir("../../queries") || return endsnap();
    asksystem("sqlplus $dbSchema/changeme\@swodb \@world_snapshot.sql") == 0 || return endsnap();

    # Here are the commands to run to do a new snapshot by hand
    # cd /swg/swg/test/exe/linux
    # rm -f *.ws snapshot.log
    # debug/SwgGameServer -- \@servercommon.cfg -s GameServer javaVMName=none -s WorldSnapshot createWorldSnapshots=/swg/swg/test/dsrc/sku.0/sys.client/built/game/snapshot/swg_object.txt 2> snapshot.log
    # p4 edit /swg/swg/test/data/sku.0/sys.client/built/game/snapshot/...
    # mv *.ws /swg/swg/test/data/sku.0/sys.client/built/game/snapshot

    # build the snapshot files "debug/SwgGameServer -- @snapshot.cfg"
    writelog("Creating snapshot files");
    chdir("${depotdir}swg/$branch/exe/linux/") || return endsnap();
    system("rm -f *.ws snapshot.log");
    system("debug/SwgGameServer -- \@servercommon.cfg -s GameServer javaVMName=none -s WorldSnapshot createWorldSnapshots=$snapShotOutputFile 2> snapshot.log") == 0 || return endsnap();

    print SOCKET SNAPSHOT_SUCCESSFULL;

    # Send snapshot log, swg_object.txt, then all ws back to controller
    writelog("Transmitting snapshot files back to the controller");
    system("cp $snapShotOutputFile ${depotdir}swg/$branch/exe/linux/swg_object.txt");
    opendir DH, "${depotdir}swg/$branch/exe/linux/" or return endsnap();
    my @files;
    foreach(readdir DH)
    {
        push @files, $_ if($_ =~ /\.ws$/ && -s "${depotdir}swg/$branch/exe/linux/$_");
    }
    closedir DH;

    @files = sort @files;
    unshift @files, "snapshot.log", "swg_object.txt";

    foreach (@files)
    {
        my $file = $_;

        my $fileSize = -s "${depotdir}swg/$branch/exe/linux/$_";
        print STDERR "Sending file $file ($fileSize bytes)\n";
        writelog("Sending file $file ($fileSize bytes)");
        print SOCKET pack("NN", $fileSize, length $file);
        print SOCKET $file;
        open(F, "<${depotdir}swg/$branch/exe/linux/$file");
            binmode(F);
            while ($fileSize)
            {
                my $buffer;
                my $readSize = 16 * 1024;
                $readSize = $fileSize if ($fileSize < $readSize);
                my $readResult = read(F, $buffer, $readSize);
                return endFunc("readResult not defined") if (!defined($readResult));
                return endFunc("readResult not equal to readSize") if ($readResult != $readSize);
                print SOCKET $buffer;
                $fileSize -= $readResult;
            }
            return endFunc("copied all the bytes but not at EOF") if (!eof(F));
        close(F);

        print STDERR "$file sent.\n";
        writelog("$file sent");
    }

    print SOCKET pack("NN", 0, 0);

    return 1;
}

sub endbootleginstall
{
    print SOCKET UPDATE_BOOTLEG_STEP_FAILED;
    return endFunc($_[0]);
}

sub bootleginstall
{
    if($accesslevel == 2)
    {
        bringdown("exe update") || errorcode("bringdown");

        writelog("Bringing down LoginServer");
        asksystem("killall -9 LoginServer");

        refreshnodes() || return endFunc("refreshnodes");
        bringnodesdown() || return endFunc("bringnodesdown");

        print STDERR "Installing most recent bootleg...\n";

        my $buffer;
        # Sync to bootleg number
        return endbootleginstall("Did not recieve enough bytes from socket (!= 4)") if (read(SOCKET, $buffer, 4) != 4);
        my $change = unpack("N", $buffer);
        print STDERR "Syncing to $change...\n";
        writelog("Syncing to $change...");
        asksystem("p4 sync //depot/swg/$branch/...\@$change 2>&1") == 0 || return endbootleginstall("p4 sync failed");
        writelog("Sync to $change complete");
        print STDERR "Sync to $change complete\n";
        print SOCKET UPDATE_BOOTLEG_STEP_OK;

        # Get exes for bootleg
        chdir("${depotdir}swg/$branch/exe/linux/") || return endbootleginstall("chdir");
        writelog("Recieving files...");

        return endbootleginstall("Did not recieve enough bytes from socket (!= 8)") if (read(SOCKET, $buffer, 2*4) != 2*4);
        my ($fileSize, $fileNameLength) = unpack("NN", $buffer);

        my $localFileName;
        return endbootleginstall("Did not recieve enough bytes from socket (!= $fileNameLength)") if (read(SOCKET, $localFileName, $fileNameLength) != $fileNameLength);

        # receive the binary bits for the file
        print STDERR "Receiving $localFileName ($fileSize bytes)\n";
        writelog("Receiving $localFileName ($fileSize bytes)");
        unlink $localFileName;
        open(F, ">" . $localFileName) || return endbootleginstall("could not open $localFileName for writing");
            chmod (0755, $localFileName);
            binmode(F);
            while ($fileSize)
            {
                my $readSize = 16 * 1024;
                $readSize = $fileSize if ($fileSize < $readSize);
                my $readResult = read(SOCKET, $buffer, $readSize);
                return endbootleginstall("socket to controller machine abruptly terminated ($fileSize bytes remained)") if (!defined($readResult));
                return endbootleginstall("read incorrect amount ($fileSize bytes remained)") if ($readResult == 0);
                print F $buffer;
                $fileSize -= $readResult;
            }
        return endbootleginstall("copied wrong number of bytes") if ($fileSize != 0);
        close(F);

        writelog("Untarring servers file");
        chdir("${depotdir}swg/$branch/exe/linux/debug");
        my $result = system("tar -xzf ../$localFileName &> /dev/null");
        return endbootleginstall("error untarring server files") if ($result != 0);
        system("chmod -R 755 *");

        print SOCKET UPDATE_BOOTLEG_STEP_OK;
        writelog("Recieve successful");

        # Update database
        print STDERR "Updating database...\n";
        writelog("Updating database");

        chdir("${depotdir}swg/$branch/src/game/server/database/build/linux/") || endbootleginstall("Cannot change to database dir $!");

        my $update_complete = 1;
        $buffer = "";
        open(DBLOG, "perl database_update.pl --delta --username=buildcluster --buildcluster |") || endbootleginstall("database_update failed");
        while(<DBLOG>)
        {
            $buffer .= $_;
            $update_complete = 0 if(/ERROR/);
        }
        close(DBLOG);

        return endbootleginstall("Error while updating database:\n$buffer") if(!$update_complete);
        print SOCKET UPDATE_BOOTLEG_STEP_OK;
        writelog("Update database complete");
        print STDERR "Update database complete\n";

        writelog("Updating individual changelists from sync.txt");
        return endFunc("Did not recieve enough bytes from socket (!= 4)") if (read(SOCKET, $buffer, 4) != 4);
        my $length = unpack("N", $buffer);
        writelog("Expecting individual changelist string of length " . $length);
        return endFunc("No changelists given") if ($length == 0);
        return endFunc("Did not recieve enough bytes from socket (!= $length)") if (read(SOCKET, $buffer, $length) != $length);
        my @changelists = split / /, $buffer;
        foreach (@changelists)
        {
            system("p4 sync //depot/swg/$branch/...\@$_,\@$_");
        }
        writelog("Done updating individual changelists from sync.txt");
        print SOCKET UPDATE_BOOTLEG_STEP_OK;

        writelog("Bringing back up LoginServer");
        chdir("${depotdir}swg/$branch/exe/linux") || return endFunc("Cannot change to ${depotdir}swg/$branch/exe/linux - $!");
        asksystem("echo start | debug/LoginServer -- \@loginServer_buildCluster.cfg 2>&1 | tee loginServer.log &") == 0 || return endbootleginstall("start LoginServer");

        bringnodesup() || return endFunc("bringnodesup");

        print STDERR "Bootleg update complete.\n";
        writelog("Bootleg update complete");
        return 1;
    }
    else
    {
        print STDERR "Not authorized to update bootleg...\n";
        return 0;
    }
}

sub getbootlegversion
{
    print STDERR "Getting bootleg version\n";
    my $bootlegver;
    open(VER, perforceWhere("//depot/swg/$branch/tools/VersionNumber") . " -r /swg/swg/$branch/exe/linux/debug/lib/libsharedFoundation.so |");
    while(<VER>)
    {
        $bootlegver = $1 if(/ \d+\.(\d+) (bootleg|publish)/);
    }
    close(VER);

    if(!defined $bootlegver)
    {
        print SOCKET pack("N", 0);
        return endFunc("Could not get VersionNumber from file");
    }

    print SOCKET pack("N", length $bootlegver);
    print SOCKET $bootlegver;
    print "Build cluster bootleg version is: $bootlegver\n";
    writelog("Build cluster bootleg version is: $bootlegver");

    return 1;
}

sub snapobjectiderror
{
    print SOCKET pack("N", 0);
    errorcode("freeobjectids");
}

sub freeobjectids
{
    print STDERR "Freeing object ids\n";

    my $tmpfile = "freeobjectids.tmp";
    open(TMPFILE, ">$tmpfile");
    print TMPFILE "exec objectidmanager.rebuild_freelist\;";
    print TMPFILE "delete from free_object_ids where end_id is null\;";
    print TMPFILE "Commit\;";
    close(TMPFILE);

    my $buffer = "";
    my $error = 0;
    open(SQL, "sqlplus buildcluster/changeme\@swodb < freeobjectids.tmp |") || return endFunc("sqlplus buildcluster/changeme\@swodb < freeobjectids.tmp");
    while(<SQL>)
    {
        $buffer .= $_;
        $error = 1 if(/ERROR/);
    }
    close(SQL);

    unlink($tmpfile);

    if($error)
    {
        writelog("Error freeing object IDs");
        writelog($buffer);
        return endFunc("freeing object ids");
    }
    else
    {
        writelog("Successfully freed object ids");
        print STDERR "Successfully freed object ids\n";
        return 1;
    }
}

sub updateversion
{
    my $dbSchema = uc shift;

    print STDERR "Updating version [$dbSchema]\n";

    my $tmpfile = "updateversion.tmp";
    open(TMPFILE, ">$tmpfile");
    print TMPFILE "UPDATE VERSION_NUMBER SET GOLDDATA='$dbSchema';\n";
    print TMPFILE "COMMIT;\n";
    close(TMPFILE);

    my $buffer = "";
    my $error = 0;

    open(SQL, "sqlplus $dbSchema/changeme\@swodb < updateversion.tmp |") || return endFunc("sqlplus $dbSchema/changeme\@swodb < updateversion.tmp");
    while(<SQL>)
    {
        $buffer .= $_;
        $error = 1 if(/ERROR/);
    }
    close(SQL);

    unlink($tmpfile);

    if($error)
    {
        writelog("Error updating version");
        writelog($buffer);
        return endFunc("update version");
    }
    else
    {
        writelog("Successfully updated version");
        print STDERR "Successfully updated version\n";
        return 1;
    }
}

sub hasuser
{
    my ($dbSchema, $dbUser, $dbPass) = @_;

    print STDERR "Checking if user exists [$dbSchema]\n";

    my $tmpfile = "hasuser.tmp";
    open(TMPFILE, ">$tmpfile");
        print TMPFILE "SELECT USERNAME FROM DBA_USERS WHERE USERNAME = '$dbSchema';\n";
    close(TMPFILE);
    my $found = 1;

    open(SQL, "sqlplus $dbUser/$dbPass\@swodb < hasuser.tmp |") || return endFunc("sqlplus < hasuser.tmp");
    while(<SQL>)
    {
        $found = 0 if(/no rows selected/);
    }
    close(SQL);

    unlink($tmpfile);

    if($found)
    {
        writelog("User found");
        print STDERR "User found\n";
    }
    else
    {
        writelog("User not found");
        print STDERR "User not found\n";
    }

    return $found;
}

sub createuser
{
    if (!defined($ENV{BUILD_CLUSTER_USER}) || !defined($ENV{BUILD_CLUSTER_PASS}))
    {
        print STDERR "DBA user environment variables not set correctly for automatic user creation\n";
        return;
    }

    my $dbSchema = uc shift;
    my $dbUser = $ENV{BUILD_CLUSTER_USER};
    my $dbPass = $ENV{BUILD_CLUSTER_PASS};

    return if hasuser($dbSchema, $dbUser, $dbPass);

    print STDERR "Creating new user [$dbSchema]\n";

    my $tmpfile = "createuser.tmp";
    open(TMPFILE, ">$tmpfile");
    print TMPFILE "CREATE USER \"$dbSchema\"  PROFILE \"DEFAULT\"\n";
    print TMPFILE "    IDENTIFIED BY \"changeme\" DEFAULT TABLESPACE \"DATA\"\n";
    print TMPFILE "    TEMPORARY TABLESPACE \"TEMP\"\n";
    print TMPFILE "    ACCOUNT UNLOCK;\n";
    print TMPFILE "GRANT CREATE TYPE TO \"$dbSchema\";\n";
    print TMPFILE "GRANT UNLIMITED TABLESPACE TO \"$dbSchema\";\n";
    print TMPFILE "GRANT \"SWG_GENERAL\" TO \"$dbSchema\";\n";
    close(TMPFILE);

    my $buffer = "";
    my $error = 0;

    open(SQL, "sqlplus $dbUser/$dbPass\@swodb < createuser.tmp |") || return endFunc("sqlplus < createuser.tmp");
    while(<SQL>)
    {
        $buffer .= $_;
        $error = 1 if(/ERROR/);
    }
    close(SQL);

    unlink($tmpfile);

    if($error)
    {
        writelog("Error creating user");
        writelog($buffer);
        return endFunc("create user");
    }
    else
    {
        writelog("Successfully created user");
        print STDERR "Successfully created user\n";
        return 1;
    }
}

sub errorcode
{
    writelog("Failed while running $_[0]");
    print STDERR "Failed while running: $_[0]\n";
    print SOCKET FAILED_COMMAND;
    bringup();
    endcommunication();
    close(SOCKET);
    goto BUILDLOOP;
}

# ======================================================================
# Main
# ======================================================================
usage() if(@ARGV != 1 && @ARGV != 3);

$branch = shift;

usage() unless ($branch =~ m/^(current|test|stage|live|x\d+|ep3|s\d+)$/);

# handle running as a daemon
# usage is $name branch [-d <directory where daemon log file should be placed>]
if (@ARGV == 2 && $ARGV[0] eq "-d")
{
    open STDIN, "/dev/null";
    open STDOUT, "/dev/null";

    # run as a daemon
    my $pid = fork;
    die "$0: fork failed" if (!defined $pid);

    # parent process should exit
    exit 0 if ($pid != 0);

    # create a new session
    setsid || die "$0: setsid failed";

    chdir($ARGV[1]) or die "cannot change directry to $ARGV[1]";

    open STDERR, "/dev/null";
}

# ignore sigpipe
$SIG{'PIPE'} = 'IGNORE';

# open the log file
open(LOG, ">>$logfile");
my $oldSelect = select(LOG);
$| = 1;
select($oldSelect);

writelog("Starting running branch $branch");

# open the daemon socket
print STDERR "Opening socket\n";
writelog("Opening socket");
socket(LISTEN, PF_INET, SOCK_STREAM, getprotobyname('tcp')) || die "socket failed\n";
setsockopt(LISTEN, SOL_SOCKET, SO_REUSEADDR, 1) || die "setsockopt failed\n";
my $addr = sockaddr_in($port, INADDR_ANY);
bind(LISTEN, $addr) || die "bind failed\n";
listen(LISTEN, 1) || die "listen failed\n";

BUILDLOOP:
while (1)
{
    print STDERR "Waiting on a connection...\n";

    accept(SOCKET, LISTEN) || die "accept failed\n";

    # make binary and unbuffer the socket
    binmode(SOCKET);
    $oldSelect = select(SOCKET);
    $| = 1;
    select($oldSelect);

    my $mode;
    goto FAIL if (read(SOCKET, $mode, 1) != 1);

    if($mode eq START_COMMUNICATION)
    {
        print STDERR "Initializing communication\n";
        writelog("Initializing communication");
        initcommunication() || errorcode("initcommunication");

        while(1)
        {
            goto FAIL if (read(SOCKET, $mode, 1) != 1);

            # Restart the build cluster
            if($mode eq COMMAND_RESTART)
            {
                writelog("Restarting");
                restart() || errorcode("restart");
                print SOCKET SUCCESSFULL_COMMAND;
            }
            # Restart the login server on the build cluster
            elsif($mode eq COMMAND_RESTART_LOGIN)
            {
                writelog("Restarting login");
                restartlogin() || errorcode("restart login");
                print SOCKET SUCCESSFULL_COMMAND;
            }
            # Restart the nodes on the build cluster
            elsif($mode eq COMMAND_RESTART_NODES)
            {
                writelog("Restarting nodes");
                restartnodes() || errorcode("restart nodes");
                print SOCKET SUCCESSFULL_COMMAND;
            }
            # Lock build cluster
            elsif($mode eq COMMAND_LOCK)
            {
                writelog("Locking");
                lockcluster() || errorcode("lock");
                print SOCKET SUCCESSFULL_COMMAND;
            }
            # Unlock build cluster
            elsif($mode eq COMMAND_UNLOCK)
            {
                writelog("Unlocking");
                unlockcluster() || errorcode("unlock");
                print SOCKET SUCCESSFULL_COMMAND;
            }
            # Bootleg
            elsif($mode eq COMMAND_UPDATE_BOOTLEG)
            {
                writelog("Update bootleg");
                bootleginstall() || errorcode("bootleginstall");
                print SOCKET SUCCESSFULL_COMMAND;
            }
            # Content sync
            elsif($mode eq COMMAND_CONTENT_SYNC)
            {
                writelog("Content syncing");
                contentsync() || errorcode("contentsync");
                print SOCKET SUCCESSFULL_COMMAND;
            }
            # Sync specific changelists
            elsif($mode eq COMMAND_SYNC_SPECIFIED_CHANGELISTS)
            {
                writelog("Changelist syncing");
                changelistsync() || errorcode("changelistsync");
                print SOCKET SUCCESSFULL_COMMAND;
            }
            # Snapshot
            elsif($mode eq COMMAND_SNAPSHOT)
            {
                writelog("Snapshot");
                freeobjectids || snapobjectiderror("freeobjectids");
                makesnap() || errorcode("makesnap");
                print SOCKET SUCCESSFULL_COMMAND;
            }
            elsif($mode eq COMMAND_BOOTLEG_VERSION)
            {
                writelog("Checking bootleg version");
                getbootlegversion() || errorcode("getbootlegversion");
                print SOCKET SUCCESSFULL_COMMAND;
            }
            elsif($mode eq COMMAND_FREE_OBJECT_IDS)
            {
                writelog("Freeing object IDs");
                freeobjectids() || errorcode("freeobjectids");
                print SOCKET SUCCESSFULL_COMMAND;
            }
            elsif($mode eq END_COMMUNICATION)
            {
                print STDERR "Ending communication\n";
                writelog("Ending communication");
                endcommunication() || errorcode("endcommunication");
                last;
            }
            else
            {
                writelog("Unrecognized command : $mode");
                goto FAIL;
            }
        }
    }
    else
    {
        errorcode("waiting for start message");
    }

FAIL:
    # done with the socket
    close(SOCKET);
}

close(LOG);
