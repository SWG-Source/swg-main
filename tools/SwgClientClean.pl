#!/usr/bin/perl -w
use BuildFunctions;


###
 # Copyright (C)2000-2002 Sony Online Entertainment Inc.
 # All Rights Reserved
 #
 # Title:        SwgClientClean.pl
 # Description:  Build release and debug SWGGameServer.  Emails the resulting log files to gmcdaniel.
 # @author       $Author: gmcdaniel $
 # @version      $Revision: #3 $
 ##



########## MAIN ##########




##
# Delete compile directory for clean build

     system("c:\\4nt302\\4nt /c del /s /y ..\\src\\compile");

#
## End of Delete compile directory for clean build




##
# Build Projects and Check for Errors

    build_project ("SwgClient");
    Check_For_Warnings_and_Errors("SwgClient","SwgClient.exe");

#
## End of Build Projects and Check for Errors


########## END OF MAIN ##########
