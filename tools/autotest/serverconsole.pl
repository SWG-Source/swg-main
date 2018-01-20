use FindBin '$Bin';
require "$Bin/passfail.pl";

sub runCommandUntil
{
    my($prefix, $command, $expect, $timeout, $evalFunc) = @_;
    
    my $startTime = time();
    my $runTime = time() - $startTime;
    my $result = "";
    if(!defined($timeout))
    {
	$timeout = 0;
    }

    do
    {
	$result = runCommand($prefix, $command);
	if($timeout > 0)
	{
	    $runTime = time() - $startTime;
	}
    } until ($result eq $expect || ($timeout > 0 && $runTime > $timeout) || (defined($evalFunc) && &$evalFunc($result)) );

    $returnValue = 0;

    if(($result eq $expect || (defined($evalFunc) && &$evalFunc($result))) && ($timeout > 0 && $timeout >= $runTime || $timeout == 0))
    {
	$returnValue = $result;
    }


    return $returnValue;

}

sub runCommand
{
    my($prefix, $command, $port) = @_;
    my $result = "";
    
    $shellCommand = "echo \"$command\" | $prefix/ServerConsole";
    if(defined($port))
    {
	$shellCommand .= " -- -s ServerConsole serverPort=$port";
    }

    $shellCommand .= " 2>&1|";


    open(COMMANDOUTPUT, $shellCommand) or fail("Failed to execute $shellCommand!\n");
    while(<COMMANDOUTPUT>)
    {
	$result .= $_;
    }
    return $result;
}

sub runTaskCommand
{
    my($prefix, $command) = @_;
    my $result = "";

    $result = runCommand($prefix, $command, 60000);
    return $result;
}

1;

