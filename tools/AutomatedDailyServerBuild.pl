#!/usr/bin/perl -w



########## MAIN ##########

     

##
# 


    print ("Synching to head\n");
    system ("p4 sync \#head");
    print ("End of sync to head\n");
    
    print ("Cleaning process...\n");
    system ("make -C ./work/swg/current/src/build/linux/ cleanall");
    print ("Cleaning Process Complete\n");
     
    
    print ("Starting Debug Server Build\n");
    system ("make -C ./work/swg/current/src/build/linux/ debug 2>&1 | tee grant debug.log");
    print ("Debug Server Build Complete\n");
    print ("\n");
    
    print ("Cleaning process...\n");
    system ("make -C ./work/swg/current/src/build/linux/ cleanall");
    print ("Cleaning Process Complete\n");
    
    
    print ("Starting Release Server Build\n");
    system ("make -C ./work/swg/current/src/build/linux/ release 2>&1 | tee grantrelease.log");
    print ("Release Server Build Complete\n");
    print ("Mailing debug log");
    system ("mail -s \"[BUILDLOG] Daily Debug Server Log\" gmcdaniel\@soe.sony.com cmayer\@soe.sony.com asommers\@soe.sony.com jgrills\@soe.sony.com jbrack\@soe.sony.com <grantdebug.log");
    print ("Mailing release log");
    system ("mail -s \"[BUILDLOG] Daily Release Server Log\" gmcdaniel\@soe.sony.com cmayer\@soe.sony.com asommers\@soe.sony.com jgrills\@soe.sony.com jbrack\@soe.sony.com <grantrelease.log");
        
#
## 



########## END OF MAIN ##########
