use FindBin '$Bin';
require "$Bin/passfail.pl";
require "$Bin/background_process.pl";

sub planetServerRunning
{
    my($prefix, $planetName) = @_;
    my $passFailMessage = "PlanetServer $planetName reports a true run state";
    my $result = runCommandUntil($prefix, "planet $planetName runState", "running", 10); 
    failOnFalse($result eq "running", $passFailMessage, $passFailMessage);
}
