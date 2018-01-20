#!/usr/bin/perl

# Script to test the environment for a server
# Looks at enviroment variables, etc., to make
# sure everything is installed

&checkJava;
&checkOracle;
&summary;

sub checkJava
{
    $ldpath=$ENV{"LD_LIBRARY_PATH"};
    if (!($ldpath =~ /java/))
    {
	&error("Java must be in LD_LIBRARY_PATH.\n");
    }
}

# Check the oracle installation
# Note:  May need to change the name of the database to 
# match whatever the production database gets called.
sub checkOracle
{   
    $ldpath=$ENV{"LD_LIBRARY_PATH"};
    if (!($ldpath =~ /oracle/))
    {
	&error("\$ORACLE_HOME/lib must be in LD_LIBRARY_PATH.\n");
    }
    $oracleHome=$ENV{"ORACLE_HOME"};
    if ($oracleHome eq "")
    {
	&error("ORACLE_HOME is not set.  Remaining Oracle tests skipped.\n");
    }
    else
    {
	open (TESTCASE,"sqlplus buildcluster/changeme\@swodb < oracletest.sql 2>&1|");
	while (<TESTCASE>)
	{
#	    print;
	    if (/ERROR/)
	    {
		$_=<TESTCASE>;
		if (/12154/) # could not resolve service name
		{
		    &error ("swodb service is not set up in \$ORACLE_HOME/network/admin/tnsnames.ora\n");
		}
		elsif (/01017/)
		{
		    &error ("Invalid username or password for Oracle.  Check that the swodb service in \$ORACLE_HOME/network/admin/tnsnames.ora is pointing to the correct database server.\n");
		}
		else
		{
		    &error ("Oracle error:  $_\n");
		}
	    }
	    if (/command not found/)
	    {
		&error ("\$ORACLE_HOME/bin is not in the path.\n");
	    }
	}
    }
}


# Display an error message and count the number of errors
sub error
{
    my ($message) = @_;
    print STDERR $message;
    ++$errorCount;
}

sub summary
{
    if ($errorCount == 0)
    {
	print "No problems detected.\n";
    }
    else
    {
	die "$errorCount problem(s) detected.\n";
    }
}
