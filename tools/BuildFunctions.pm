package BuildFunctions;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(build_project Check_For_Warnings_and_Errors get_time_and_date get_date);



###
 # Copyright (C)2000-2002 Sony Online Entertainment Inc.
 # All Rights Reserved
 #
 # Title:        BuildFunctions.pl
 # Description:  This file contains the various functions used by the different build scripts.
 # @author       $Author: gmcdaniel $
 # @version      $Revision: #1 $
 ##






#todo  Possible failure points that I need to fix.  The ResultsLogfile file can fail to be opened in one sub but still try to be written to in Check_Logfile_For_Warnings_and_Errors
#todo  Bad coding to call ResultsLogFile without acutally passing it in to the sub?  Probably



##
# This subroutine builds the passed project.  It is passed the project name, the string for the project to build, and the project type (release or debug) 

sub build  
{
	print ("Beginning $_[1] build...\n");
	system("msdev ..\\src\\build\\win32\\swg.dsw /MAKE \"$_[1]\" /y3 /REBUILD /OUT d:\\buildlogs\\$_[0]_$_[2].log");	
	print ("$_[1] build complete\n");
	print ("\n");
        $timestamp = get_time_and_date();
	$timeStamped_Log = $_[0]."_".$_[2]."_".$timestamp.".log";
	system ("copy d:\\buildlogs\\$_[0]_$_[2].log d:\\buildlogs\\$timeStamped_Log");
        print ("\n");
        print ("\n");
	    
	
} # End of sub build




##
# This subroutine calls the build subroutine to build both the release and debug versions of the project that is passed

sub build_project  
{
	
	$project = $_[0]." - Win32 Release";
	$type = "Release";
	build($_[0],$project,$type);
	
	
	$project = $_[0]." - Win32 Debug";
	$type = "Debug";
	build($_[0],$project,$type);
	
	
	$project = $_[0]." - Win32 Optimized";
	$type = "Optimized";
	build($_[0],$project,$type);
	
} # End of sub build_project




##
# This subroutine returns the current local time and date

sub get_time_and_date 
{
	($sec, $min, $hour, $day, $month, $year) = (localtime) [0,1,2,3,4,5];
	$month = $month + 1;
	$year = $year + 1900;
	$dayandtime = $month."_".$day."_".$year."__".$hour."_".$min."_".$sec;
	return $dayandtime;

} # End of sub get_time_and_date




##
# This subroutine returns the current local date

sub get_date 
{
	($day, $month, $year) = (localtime) [3,4,5];
	$month = $month + 1;
	$year = $year + 1900;
	$date = $month."/".$day."/".$year;
	return $date;

} # End of sub get_date




##  
# This subroutine checks for warnings and errors in the build logs.  If there is an error it returns true otherwise it returns false.
# It takes the name the logfile to check and the resulting exe or project name as input.

sub Check_Logfile_For_Warnings_and_Errors
{
    
       $third_to_last_line = "test_line_3";
       $second_to_last_line = "test_line_2";
     
       open (Logfile,"d:\\buildlogs\\$_[0]") || die "Cannot open $_[0] for reading.";
       while (<Logfile>)
       {
           chomp;
           $third_to_last_line = $second_to_last_line;
           $second_to_last_line = $_;
       }
       close (Logfile)  || die "can't close $_[0]";
       print ("\n");
       print ("$third_to_last_line\n");
       print ("$second_to_last_line\n");
       print ResultsLogfile ("$third_to_last_line\n");
       print ResultsLogfile ("$second_to_last_line\n");
       print ResultsLogfile ("\n");
     


       
       $search_for_errors= "0 error";
       $search_for_warnings= "0 warning";
       $match=-1;	
       
       #check for 0 errors.
       if (index($third_to_last_line, $search_for_errors,$match) > -1) {
           print ("No errors Found in $_[0]\n");
           print ("\n");
           
           #check for warnings
           if (index($third_to_last_line, $search_for_warnings,$match) > -1) {
	              #no warnings or errors found
	              print ("No Warnings Found in $_[0]\n");
	              print ("\n");
	              return "false";
           }
           #a warning was found
           print ("Warning Found in $_[0]\n");
           print ("\n");
           return "true";
       }
       
       #an error was found
       else {
           print ("Error Found in $_[0]\n");
           print ("\n");
           return "true";
       }
  
       
} # End of sub Check_Logfile_For_Warnings_and_Errors




##  
# This subroutine checks for warnings and errors in the build logs.  If there is an error or warning it notifies QA and the lead programmers.
# If there is not an error or warning then the build log is just sent to QA.
# It takes the name of the project and the resulting exe or project name as input.

sub Check_For_Warnings_and_Errors
{
     
     print ("Checking for errors and warnings...\n");
     print ("\n");
         
     # create file to store warnings and errors for inclusion in body of email.
     open (ResultsLogfile, ">d:\\buildlogs\\$_[0]Results.log") || die "Sorry, I couldn't create $_[0]Results.log";
     
         
                       
     # Prints to results file for easier email formatting
     print ResultsLogfile ("\n");
     print ResultsLogfile ("Release Build:\n");
     
     
     # Checks for errors or warnings in the release build
     $Logfile_to_check = $_[0]."_Release.log";
     $ReleaseError = Check_Logfile_For_Warnings_and_Errors($Logfile_to_check);
            
            
     # Prints to results file for easier email formatting
     print ResultsLogfile ("\n");      
     print ResultsLogfile ("Debug Build:\n");     
            
            
     # Checks for errors or warnings in the debug build
     $Logfile_to_check = $_[0]."_Debug.log";
     $DebugError = Check_Logfile_For_Warnings_and_Errors($Logfile_to_check);
     
     
     
     # Prints to results file for easier email formatting
     print ResultsLogfile ("\n");      
     print ResultsLogfile ("Optimized Build:\n");     
                 
                 
     # Checks for errors or warnings in the debug build
     $Logfile_to_check = $_[0]."_Optimized.log";
     $OptimizedError = Check_Logfile_For_Warnings_and_Errors($Logfile_to_check);
     
     
     # Closes file used for the number of errors and warnings
     close (ResultsLogfile);
     
      
     
       
       
     # Email addresses
     $gmcdaniel = "gmcdaniel\@soe.sony.com";
     $jbrack = "jbrack\@soe.sony.com";
     $jgrills = "jgrills\@soe.sony.com";
     $asommers = "asommers\@soe.sony.com";
     $cmayer = "cmayer\@soe.sony.com";
     $prog_leads = "-to:$gmcdaniel -to:$jgrills -to:$cmayer -to:$asommers -cc:$jbrack";
     
     
     
     $date_stamp = get_date();

    if ($ReleaseError eq "true")
    {
        print ("Error or warning found in $_[0] Release Log.  Emailing appropriate people.\n");
         
        # Email the results to Programmer Leads and QA
        system ("postie -host:sdt-mx1.station.sony.com $prog_leads -from:$gmcdaniel -s:\"[BUILDLOG] Errors or Warnings in Daily $_[0] Build Logs $date_stamp\" -nomsg -file:d:\\buildlogs\\$_[0]Results.log -a:d:\\buildlogs\\$_[0]_Release.log  -a:d:\\buildlogs\\$_[0]_Debug.log -a:d:\\buildlogs\\$_[0]_Optimized.log");
     }
      
     elsif ($DebugError eq "true")
     {
        print ("Error or warning found in $_[0] Debug Log.  Emailing appropriate people.\n");
        
        # Email the results to Programmer Leads and QA
        system ("postie -host:sdt-mx1.station.sony.com $prog_leads -from:$gmcdaniel -s:\"[BUILDLOG] Errors or Warnings in Daily $_[0] Build Logs $date_stamp\" -nomsg -file:d:\\buildlogs\\$_[0]Results.log -a:d:\\buildlogs\\$_[0]_Release.log  -a:d:\\buildlogs\\$_[0]_Debug.log -a:d:\\buildlogs\\$_[0]_Optimized.log");     
     }
      
     elsif ($OptimizedError eq "true")
     {
        print ("Error or warning found in $_[0] Optimized Log.  Emailing appropriate people.\n");
              
        # Email the results to Programmer Leads and QA
        system ("postie -host:sdt-mx1.station.sony.com $prog_leads -from:$gmcdaniel -s:\"[BUILDLOG] Errors or Warnings in Daily $_[0] Build Logs $date_stamp\" -nomsg -file:d:\\buildlogs\\$_[0]Results.log -a:d:\\buildlogs\\$_[0]_Release.log  -a:d:\\buildlogs\\$_[0]_Debug.log -a:d:\\buildlogs\\$_[0]_Optimized.log");     
     }
     
     else
     {
        print ("No errors or warnings found in $_[0] logs.");
        
        # Email the results to QA and Programmer Leads
        system ("postie -host:sdt-mx1.station.sony.com $prog_leads -from:$gmcdaniel -s:\"[BUILDLOG] $_[0] Build Successful $date_stamp\" -nomsg -file:d:\\buildlogs\\$_[0]Results.log");
     }
               

     
     print ("End of errors and warning check for $_[0] logs.\n");
     print ("\n");


} # End of sub Check_For_Warnings_and_Errors


1;
