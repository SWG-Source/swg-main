use FindBin '$Bin';
require "$Bin/passfail.pl";
require "$Bin/background_process.pl";

sub databaseServerRunning
{
    my($prefix) = @_;
    my $result = runCommand($prefix, "database runState");
    my $testMessage = "DatabaseServer reports a true run state";
    failOnFalse($result eq "running", $testMessage, $testMessage);
}

1;
