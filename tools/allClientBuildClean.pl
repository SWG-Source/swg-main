#!/usr/bin/perl -w
use BuildFunctions;

### 
 # Copyright (C)2000-2002 Sony Online Entertainment Inc.
 # All Rights Reserved
 #
 # Title:        allClientBuildClean.pl
 # Description:  Builds all_Client debug and release and sends log files to gmcdaniel
 # @author       $Author: gmcdaniel $
 # @version      $Revision: #3 $
###






########## MAIN ##########



##
# Delete compile directory for clean build

     system("c:\\4nt302\\4nt /c del /s /y ..\\src\\compile");

#
## End of Delete compile directory for clean build




##
# Build Projects and Check for Errors

    build_project ("_all_client");
    Check_For_Warnings_and_Errors("_all_client","_all_client");

#
## End of Build Projects and Check for Errors




########## END OF MAIN ##########
