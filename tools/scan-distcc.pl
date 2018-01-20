#!/bin/env perl

use FindBin '$Bin';

# list of ips to ignore - build machines
my @ignoreList = 
(
	"64.37.133.41",   # aus-linbld1.station.sony.com.
	"64.37.133.230",  # aus-linbldfm1.station.sony.com.
	"64.37.133.231",  # aus-linbldfm2.station.sony.com.
	"64.37.133.232",  # aus-linbldfm3.station.sony.com.
	"64.37.133.233",  # aus-linbldfm4.station.sony.com.
	"64.37.133.234",  # aus-linbldfm5.station.sony.com.
	"64.37.133.235",  # aus-linbldfm6.station.sony.com.
	"64.37.133.236",  # aus-linbld2.station.sony.com.
	"64.37.133.238",  # aus-linbld3.station.sony.com.
	"64.37.133.241",  # aus-lindtbld1.station.sony.com.	
	"64.37.133.242",
	"64.37.133.243",
	"64.37.133.7"     # aus-ups1.sonyonline.net.
);

# if nmap is available
# $scanText = `nmap -sT -n -p 3632 -oG - $ARGV[0] | grep open | cut -f2 -d\" \"  | tr [:space:] \" \"`;

$netBase = $ARGV[0];
$scanText = "";
$port = shift || 3632;

for( $i = 1; $i < 255; ++$i)
{
	next if (grep($_ eq "$netBase.$i", @ignoreList));
	$scanText = "$scanText $netBase\.$i";
}

@hostList = split(' ', $scanText);

open(OUTFILE, ">/tmp/tmp.c");
print OUTFILE "int main(int argc, char ** argv) { return 0; }";
close(OUTFILE);

$myCCVer = `gcc -dumpversion`;

for $host(@hostList)
{
      warn "scanning: $host\n";
      eval
      {
         local $SIG{ALRM} = sub { die "alarm clock restart" };
         alarm 10;
         $remoteVersion = `DISTCC_HOSTS="$host" CCACHE_DISABLE='1' DISTCC_FALLBACK='0' gcc -dumpversion -c /tmp/tmp.c 2>/dev/null`;
         alarm 0;
      };
      # skip hosts that do not respond within 10 sec
      if ($@)
      {
         if ($@ =~ /alarm clock restart/)
         {
            warn "TIMED OUT: $host\n";
            next;
         }
         else
         {
            die $@;
         }
     }

     if($remoteVersion == $myCCVer)
     {
         warn "ADDED: $host\n";
         push(@validHosts, $host);
     }
}

my @scrambledHosts;
my %scrambled;
for($i = 0; $i < @validHosts; ++$i)
{
    $index = int(rand(@validHosts));
    while(exists($scrambled{$index}))
    {
	$index = int(rand(@validHosts));
    }
    $scrambled{$index} = 1;
    @scrambledHosts[$i] = @validHosts[$index];
}

for $goodHost(@scrambledHosts)
{
    print "$goodHost\n";
}
print "localhost\n";

