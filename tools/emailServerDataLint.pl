#!/usr/bin/perl -w
use File::stat;



###
 # Copyright (C)2000-2002 Sony Online Entertainment Inc.
 # All Rights Reserved
 #
 # Title:        emailDataLint.pl
 # Description:  emails datalint generated server files to appropriate people
 # @author       $Author: gmcdaniel $
 # @version      $Revision: #1 $
 ##



#todo Once the command line parameter of where to drop the files is added I can move this script back out of the exe\win32 directory.
#todo Change the taskmanager to point to the new script location once above change happens.
#todo Email may not work unless client does not crash.





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
# This subroutine checks for warnings and errors in the datalint txt files.  If there is an error it returns true otherwise it returns false.
# It takes the name of the txt file to check as input.

sub Check_Logfile_For_Warnings_and_Errors
{
    
       $second_to_last_line = "current_line_2";
     
       open (Logfile,"C:\\$work_path\\swg\\test\\exe\\win32\\$_[0].txt") || die "Cannot open $_[0] for reading.";
       while (<Logfile>)
       {
           chomp;
           $second_to_last_line = $_;
       }
       close (Logfile)  || die "can't close $_[0]";
       print ("\n");
       
       
       if ($second_to_last_line eq "current_line_2")
       {
           print ("No warnings or fatals found in $_[0]\n");
           print ("\n");
           return "false";
       }
       else
       { 	
           print ("Warnings or errors found in $_[0]\n");
           print ("\n");
           return "true";
       }

} # End of sub Check_Logfile_For_Warnings_and_Errors




##
# This subroutine checks for the existance of errors and fatals in the datalint logs.  The logs are then sent to the appropriate people.
# It takes the name of the logfile to check and a string with the list if email addresses to mail if there are errors.

sub check_and_email_datalint_logs
{
  
       $date_stamp = get_date();


       $Error = Check_Logfile_For_Warnings_and_Errors($_[0]);
           
       if ($Error eq "true")
       {
       
            #Check size of file to see if it should be zipped or not
       
            $LogFile="C:\\$work_path\\swg\\test\\exe\\win32\\$_[0].txt";
            $info=stat($LogFile);
            $sizeOfFile = $info->size;
            
	    if ($sizeOfFile < 512)
	    {
               print ("Error or warning found in $_[0].  Emailing appropriate people.\n");
               system ("c:\\postie\\postie -host:mail-sd.station.sony.com $_[1] -from:$gmcdaniel -s:\"[DataLint] Errors or Warnings in $_[0] $date_stamp\" -msg:\"Attached is $_[0] listing the asset warnings and errors as found by DataLint.  Let me know if you have any questions.   Thanks,Grant\" -a:c:\\$work_path\\swg\\test\\exe\\win32\\$_[0].txt");
            }
         
            else
            {
               print ("Error or warning found in $_[0].  Emailing appropriate people.\n");
	       print ("File to large to send, zipping");
	       system ("c:\\progra~1\\winzip\\wzzip.exe c:\\$work_path\\swg\\test\\exe\\win32\\$_[0].zip $LogFile"); 
	       system ("c:\\postie\\postie -host:mail-sd.station.sony.com $_[1] -from:$gmcdaniel -s:\"[DataLint] Errors or Warnings in $_[0] $date_stamp\" -msg:\"Attached is $_[0] listing the asset warnings and errors as found by DataLint.  Let me know if you have any questions.   Thanks,Grant\" -a:c:\\$work_path\\swg\\test\\exe\\win32\\$_[0].zip");
            
            }
       
       
       }  
       
                 
       else
       {
          print ("No errors or warnings found in $_[0].");
          system ("c:\\postie\\postie -host:mail-sd.station.sony.com $gmcdaniel -from:$gmcdaniel -s:\"[DataLint] $_[0] $date_stamp\" -nomsg -a:c:\\$work_path\\swg\\test\\exe\\win32\\$_[0].txt");
       }
           


} # End of sub check_and_email_datalint_logs







########## MAIN ##########



$work_path = "workpublish";



##
# Runs DataLintRspBuilder and DataLint


    print ("Beginning DataLintRspBuilder...\n");
    #system ("copy c:\\work\\swg\\test\\tools\\DataLintRspBuilder.exe c:\\$work_path\\swg\\test\\exe\\win32\\DataLintRspBuilder.exe");
    #system ("c:\\$work_path\\swg\\test\\exe\\win32\\DataLintRspBuilder.exe c:\\$work_path\\swg\\test\\exe\\win32\\common.cfg");
    print ("DataLintRspBuilder Complete\n");
    print ("\n");
    print ("\n");


    print ("Beginning DataLint...\n");
    #system ("c:\\$work_path\\swg\\test\\exe\\win32\\SwgClient_d.exe -- -s DataLint disable=0 -s SharedFoundation demo Mode=1");
    print ("DataLint Complete\n");
    print ("\n");
    print ("\n");
   
#
## End of Runs DataLintRspBuilder and DataLint






##  Check_For_Warnings_and_Errors
#
     
     print ("Checking for errors and warnings...\n");
     print ("\n");
         
     
     # Email addresses
     $gmcdaniel = "gmcdaniel\@soe.sony.com";
     $jbrack = "jbrack\@soe.sony.com";
     $jgrills = "jgrills\@soe.sony.com";
     $asommers = "asommers\@soe.sony.com";
     $cmayer = "cmayer\@soe.sony.com";
     $jrodgers = "jrodgers\@soe.sony.com";
     $jroy = "jroy\@soe.sony.com";
     $jshoopack = "jshoopack\@soe.sony.com";
     #$acastoro = "acastoro\@soe.sony.com";
     $cbarnes = "cbarnes\@soe.sony.com";
     $rkoster = "rkoster\@soe.sony.com";
     $jdonham = "jdonham\@soe.sony.com";
     $rvogel = "rvogel\@soe.sony.com";
     $mhigby = "mhigby\@soe.sony.com";
     $ssnopel = "ssnopel\@soe.sony.com";
     $jwhisenant = "jwhisenant\@soe.sony.com";
     
     
     
     $swo_leads = "-to:$cmayer -to:$asommers -to:$jgrills -to:$jrodgers -to:$jroy -to:$jshoopack -to:$cbarnes -to:$rkoster -cc:$gmcdaniel -cc:$jbrack -cc:$jdonham -cc:$rvogel -cc:$ssnopel -cc:$jwhisenant";
     $prog_leads = "-to:$cmayer -to:$asommers -to:$jgrills -cc:$gmcdaniel -cc:$jbrack  -cc:$ssnopel -cc:$jwhisenant";
     $art_leads = "-to:$jrodgers -to:$jroy -to:$jshoopack -cc:$gmcdaniel -cc:$jbrack  -cc:$ssnopel -cc:$jwhisenant";
     $design_leads = "-to:$cbarnes -to:$rkoster -cc:$gmcdaniel -cc:$jbrack  -cc:$ssnopel -cc:$jwhisenant";
     $art_and_design_leads = "-to:$cbarnes -to:$rkoster -to:$jrodgers -to:$jroy -to:$jshoopack -cc:$gmcdaniel -cc:$jbrack  -cc:$ssnopel -cc:$jwhisenant";
     $qa_leads = "-to:$gmcdaniel -to:$ssnopel -to:$jwhisenant";

    
     
     check_and_email_datalint_logs("DataLintServer_Errors_All",$swo_leads);
     
     check_and_email_datalint_logs("DataLintServer_Errors_All_Fatal",$swo_leads);
          
     check_and_email_datalint_logs("DataLintServer_Errors_ObjectTemplate",$design_leads);
      
          
     
     
     
     print ("End of errors and warnings check for DataLint files.\n");
     print ("\n");

#
## End of Check_For_Warnings_and_Errors







########## END OF MAIN ##########
