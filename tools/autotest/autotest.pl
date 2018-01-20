use POSIX ":sys_wait_h";
use FindBin '$Bin';
require "$Bin/taskmanager.pl";
require "$Bin/centralserver.pl";
require "$Bin/passfail.pl";
require "$Bin/loginserver.pl";
require "$Bin/databaseserver.pl";
require "$Bin/planetserver.pl";

$target = $ARGV[0];

my $testPlanet = "tatooine";

if($target eq "")
{
    fail("target (debug or release) not specified in test script\n");
}

#taskmanagerStartupShutdown($target);
#centralServerStartupShutdown($target);

loginServerStartup($target);
clusterStartup($target);
centralServerRunning($target);
databaseServerConnectedToCentralServer($target);
databaseServerRunning($target);
planetServerConnected($target);
hasPlanetServer($target, $testPlanet);
planetServerRunning($target, $testPlanet);
# gameServerRunning($target);
# chatServerRunning($target);
# commoditiesServerRunning($target);
# connectionServerRunning($target);
# customerServiceServerRunning($target);
# logServerRunning($target);
# metricsServerRunning($target);
# transferServerRunning($target);
# clusterIsReady($target);
loginServerShutdown($target);
clusterShutdown($target);
