use POSIX ":sys_wait_h";
use FindBin '$Bin';
require "$Bin/passfail.pl";

sub backgroundProcess
{
    my($prefix, $program, $timeout, $funcPtr) = @_;
    $cmd = "$prefix/$program";
    $childId = fork();
    if($childId == 0)
    {
	$result = system("$cmd");
	exit($result);
    }
    else
    {
	$runTime = time();
	do
	{
	    $elapsed = time() - $runTime;
	    if($elapsed > $timeout)
	    {
		kill(11, $childId);
		chomp($cwd = `pwd`);
		fail("$cmd did not exit in time. Sending SIGSEGV to force a core dump in $cwd");
	    }
	    
	    if(defined($funcPtr))
	    {
		&$funcPtr();
	    }

	    $kid = waitpid($childId, WNOHANG);
	} until $kid > 0 ;
	
	$taskResult = $?;
	if($taskResult != 0)
	{
	    fail("$cmd did not exit cleanly!!");
	}
    }
    return 1;
}

sub startBackgroundProcess
{
    my($prefix, $program, $timeout, $funcPtr) = @_;
    $cmd = "$prefix/$program";
    $childId = fork();
    if($childId == 0)
    {
	$result = system("$cmd");
	exit($result);
    }
    else
    {
	$runTime = time();
	do
	{
	    $elapsed = time() - $runTime;
	    if($elapsed > $timeout)
	    {
		kill(11, $childId);
		chomp($cwd = `pwd`);
		fail("$cmd did not respond to run query in time. Sending SIGSEGV to force core dump in $cwd");
	    }
	    
	    $functionResult = 0;
	    if(defined($funcPtr))
	    {
		$functionResult = &$funcPtr();
	    }
	    else
	    {
		$functionResult = 1;
	    }

	    $kid = waitpid($childId, WNOHANG);
	} until $kid > 0 || $functionResult != 0;

	$taskResult = $?;
	if(defined($funcPtr))
	{
	    if($functionResult == -1)
	    {
		fail("run query function for $cmd returned -1. Failed to start background process.");
	    }
	}
	elsif($kid > 0 && $taskResult != 0)
	{
	    fail("$cmd failed to start properly");
	}
	
    }
    return $childId;
}

1;
