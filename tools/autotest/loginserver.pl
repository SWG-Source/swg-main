use FindBin '$Bin';
require "$Bin/passfail.pl";
require "$Bin/background_process.pl";

$loginServerPid = 0;

sub loginServerStartup
{
    $passFailMessage = "LoginServer startup";
    my($prefix) = @_;

    # determin the user id
    $uid = getpwuid($<);
    
    my $branch = "";
    #determing the branch
    @dirs = split('/', $Bin);
    $x = 0;
    for $i(@dirs)
    {
	if($i eq "swg")
	{
	    if(@dirs[$x+2] eq "tools")
	    {
		$branch = @dirs[$x+1];
		break;
	    }
	}
	$x++;
    }

    $dbuid = "$uid\_$branch";

    $loginServerPid = startBackgroundProcess($prefix, "LoginServer -- -s LoginServer databaseProtocol=OCI DSN=swodb databaseUID=$dbuid databasePWD=changeme 2>/dev/null", 10);
    failOnFalse($loginServerPid, $passFailMessage, $passFailMessage);
}

sub loginServerShutdown
{
    if($loginServerPid != 0)
    {
	$kid = 0;
	do
	{
	    $kid = waitpid($loginServerPid, WNOHANG);
	    if($kid == 0)
	    {
		system("echo \"login exit\" | debug/ServerConsole -- -s ServerConsole > /dev/null");
	    }
	} until $kid > 0;
	failOnFalse($? == 0, "LoginServer shutdown", "LoginServer shutdown");
    }
}

1;
