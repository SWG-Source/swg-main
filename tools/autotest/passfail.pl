sub pass
{
    my ($message) = @_;
    print "PASS: $message\n";
}

sub fail
{
    my ($message) = @_;
    print "FAIL: $message\n";
    exit(1);
}

sub failOnFalse 
{
    my ($result, $failMessage, $passMessage) = @_;

    if($result == 0)
    {
	fail($failMessage);
    }
    else
    {
	pass($passMessage);
    }
}

1;
