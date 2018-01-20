use FindBin '$Bin';
require "$Bin/passfail.pl";
require "$Bin/background_process.pl";
require "$Bin/serverconsole.pl";

$taskManagerPid = 0;
sub taskmanagerStartupShutdown
{
    my ($prefix) = @_;
    $passFailMessage = "TaskManager startup and shutdown";
    failOnFalse(backgroundProcess($prefix, "TaskManager -- -s TaskManager autoStart=false 2>/dev/null", 10, sub {system("echo \"exit\" | debug/ServerConsole -- -s ServerConsole serverPort=60000 > /dev/null");}), $passFailMessage, $passFailMessage);
}

sub clusterStartup
{
    my ($prefix) = @_;
    $passFailMessage = "TaskManager cluster startup";
    $taskManagerPid = startBackgroundProcess($prefix, "TaskManager -- \@taskmanager.cfg 2>/dev/null", 10, sub { return 1; });
    $result = "";
    do
    {
	$result = runTaskCommand($prefix, "runState");
    } until($result eq "running");

    failOnFalse($taskManagerPid > 0, $passFailMessage, $passFailMessage);
    
    do
    {
	$result = runCommand($prefix, "runState");
    } until($result eq "running");

    pass("CentralServer cluster startup");
}

sub clusterShutdown
{
    my ($prefix) = @_;
    do
    {
	$result = runTaskCommand($prefix, "exit");
    } until($result eq "exiting");
}

1;
