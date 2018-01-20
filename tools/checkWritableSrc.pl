#!/usr/bin/perl -w
use File::Find;
use BuildFunctions;



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

# Email addresses
$gmcdaniel = "gmcdaniel\@soe.sony.com";
     

##
# Check for any non-authorized writable files in the /swg/current/src directory and email the results

    $writable_files_log = "WritableFiles.log";
     
    print ("Checking for writable files...\n");
    open (Logfile, ">c:\\buildlogs\\$writable_files_log") || die "Sorry, I couldn't create $writable_files_log";
    print Logfile "The writable files that were found:\n";
    
    # do a find
    $search_path = "..\\src";
    @ARGV = ($search_path);
    find(\&Find_Writable, @ARGV);
    
    close (Logfile);
    
    $writable_test_time_and_date = get_time_and_date();
    $date_stamp = get_date();
    system ("copy c:\\buildlogs\\$writable_files_log c:\\buildlogs\\WritableFiles_$writable_test_time_and_date.log");
    print ("Checking for writable files completed\n");
    print ("\n");
    print ("\n");
    system ("postie -host:mail-sd.station.sony.com -to:$gmcdaniel -from:$gmcdaniel -s:\"Writable Files Results $date_stamp\" -nomsg -file:c:\\buildlogs\\WritableFiles_$writable_test_time_and_date.log");
        
#
## End of Check for any non-authorized writable files in the /swg/current/src directory and email the results




########## END OF MAIN ##########
