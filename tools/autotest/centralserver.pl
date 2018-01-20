use FindBin '$Bin';
require "$Bin/passfail.pl";
require "$Bin/background_process.pl";

sub centralServerStartupShutdown
{
    $passFailMessage = "CentralServer startup and shutdown";
    my($prefix) = @_;
    failOnFalse(backgroundProcess($prefix, "CentralServer -- -s CentralServer shutdown=true 2>/dev/null", 10), $passFailMessage, $passFailMessage);
}

sub centralServerRunning
{
    my($prefix) = @_;
    my $result = runCommand($prefix, "runState");
    my $testMessage = "CentralServer running";
    failOnFalse($result eq "running", $testMessage, $testMessage);
}

sub databaseServerConnectedToCentralServer
{
    my($prefix) = @_;
    my $result = "";
    my $passFailMessage = "DatabaseServer connected to CentralServer";

    # test that the database server has connected to the 
    # central server by querying Central for a db connection.
    # poll CentralServer repeatedly until it responds with a "1"
    # or more than 10 seconds has passed
    failOnFalse(runCommandUntil($prefix, "dbconnected", "1", 10), $passFailMessage, $passFailMessage);
}

sub planetServerConnected
{
    my($prefix) = @_;
    my $passFailMessage = "PlanetServer connected to CentralServer";
    failOnFalse(runCommandUntil($prefix, "getPlanetServersCount", "1", 10, sub { $_[0] > 0; }), $passFailMessage, $passFailMessage);
}

sub hasPlanetServer
{
    my($prefix, $planetName) = @_;
    my $passFailMessage = "PlanetServer for $planetName is connected to CentralServer";
    failOnFalse(runCommandUntil($prefix, "hasPlanetServer $planetName", "1", 10), $passFailMessage, $passFailMessage);
}
