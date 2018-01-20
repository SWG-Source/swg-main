#!/usr/bin/perl -w
use BuildFunctions;


###
 # Copyright (C)2000-2002 Sony Online Entertainment Inc.
 # All Rights Reserved
 #
 # Title:        publishBuildClean.pl
 # Description:  Builds release and debug all_Client, SWGGameServer, and PlanetServer from scratch.  Emails resulting logfiles to gmcdaniel.
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

    build_project ("_all_client");
    Check_For_Warnings_and_Errors("_all_client","_all_client");

    build_project ("PlanetServer");
    Check_For_Warnings_and_Errors("PlanetServer","PlanetServer.exe");
    
    build_project ("SwgGameServer");
    Check_For_Warnings_and_Errors("SwgGameServer","SwgGameServer.exe");

#
## End of Build Projects and Check for Errors




########## END OF MAIN ##########
