#!/usr/bin/perl -w
use BuildFunctions;



###
 # Copyright (C)2000-2002 Sony Online Entertainment Inc.
 # All Rights Reserved
 #
 # Title:        planetServerClean.pl
 # Description:  Builds debug and release PlanetServer and emails resulting log files to gmcdaniel.
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

    build_project ("PlanetServer");
    Check_For_Warnings_and_Errors("PlanetServer","PlanetServer.exe");

#
## End of Build Projects and Check for Errors



########## END OF MAIN ##########
