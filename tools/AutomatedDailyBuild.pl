#!/usr/bin/perl -w
use File::Find;
use BuildFunctions;


###
 # Copyright (C)2000-2002 Sony Online Entertainment Inc.
 # All Rights Reserved
 #
 # Title:        AutomatedDailyBuild.pl
 # Description:  Forces a sync to current, syncs to head, builds all_Client, SWGGameServer, PlanetServer, and SwgLoadServer and check for writable files in the src directory then emails log files to gmcdaniel.
 # @author       $Author: gmcdaniel $
 # @version      $Revision: #17 $
 ##


##
# This subroutine finds any non-authorized writable files in a passed directory

sub Find_Writable 
{
    if (-d $_)
    {
	# found a directory entry
	
	# prune the directory if it's one we want to ignore
	if (m/^(compile)$/)
	{
	     #prune it
	    $File::Find::prune = 1;
	}
    }
    elsif (-f and -w $_)
    {	if (!m/^.*(aps|ncb|opt|plg)$/)
	{
	    print "n $File::Find::name\n";
	    print Logfile "n $File::Find::name\n";
	}
    }
}  # End of sub Find_Writable



########## MAIN ##########



##
# Delete compile directory for clean build

     system("c:\\4nt302\\4nt /c del /s /y ..\\src\\compile");

#
## End of Delete compile directory for clean build



##
# Sync Code to Head

    print ("Beginning Sync to Head...\n");
    # sync client that points to d:\workdaily
    system ("p4 -c gmcdaniel-wxp-gmcdaniel-build-station-machine_daily_build sync //depot/swg...\#head");
    print ("Sync Complete\n");
    print ("\n");
    print ("\n");

#
## End of Sync Code to Head



##
# Forced Code

    print ("Beginning Forced Sync...\n");
    # sync client that points to d:\workdaily
    system ("p4 -c gmcdaniel-wxp-gmcdaniel-build-station-machine_daily_build sync -f //depot/swg...\#have");
    print ("Sync Complete\n");
    print ("\n");
    print ("\n");

#
## End of Forced Sync




##
# Build Projects and Check for Errors

    build_project ("_all_client");
    Check_For_Warnings_and_Errors("_all_client");

    #build_project ("PlanetServer");
    #Check_For_Warnings_and_Errors("PlanetServer");
   
    #build_project ("SwgGameServer");
    #Check_For_Warnings_and_Errors("SwgGameServer");
    
    #build_project ("SwgLoadClient");
    #Check_For_Warnings_and_Errors("SwgLoadClient");

#
## End of Build Projects and Check for Errors





##
# Check for any non-authorized writable files in the /swg/current/src directory and email the results



    ### Email addresses
    #$gmcdaniel = "gmcdaniel\@soe.sony.com";
    
    
    #$writable_files_log = "WritableFiles.log";
     
    #print ("Checking for writable files...\n");
    #open (Logfile, ">d:\\buildlogs\\$writable_files_log") || die "Sorry, I couldn't create $writable_files_log";
    #print Logfile "The writable files that were found:\n";
    
    # do a find
    #$search_path = "..\\src";
    #@ARGV = ($search_path);
    #find(\&Find_Writable, @ARGV);
    
    #close (Logfile);
    
    #$writable_test_time_and_date = get_time_and_date();
    #$date_stamp = get_date();
    #system ("copy d:\\buildlogs\\$writable_files_log d:\\buildlogs\\WritableFiles_$writable_test_time_and_date.log");
    #print ("Checking for writable files completed\n");
    #print ("\n");
    #print ("\n");
    #system ("postie -host:sdt-mx1.station.sony.com -to:$gmcdaniel -from:$gmcdaniel -s:\"Writable Files Results $date_stamp\" -nomsg -file:d:\\buildlogs\\WritableFiles_$writable_test_time_and_date.log");
        
#
## End of Check for any non-authorized writable files in the /swg/current/src directory and email the results



########## END OF MAIN ##########
