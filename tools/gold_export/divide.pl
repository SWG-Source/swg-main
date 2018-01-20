#!/usr/bin/perl

use POSIX;

my $sharedTemplateDir = "/c/work/swg/s7/data/sku.0/sys.shared/compiled/game/";

$planet = $ARGV[0];
print $planet."\n";

#############################################################################

sub floor
{
	$value = @_[0];
	
	if ( $value >= 0 )
	{
		return int( $value );
	}
	
	return int( $value ) - 1;
}

#############################################################################

sub _fmod
{
	$value = @_[0];
	$mod   = @_[1];
	
	if ( $value >= 0 )
	{
		return POSIX::fmod($value,$mod);
	}
	
	return $mod + POSIX::fmod($value,$mod);
}

#############################################################################

#
# load templates
#

open( INPUT, "templates.dat" ) || die $!;

while (<INPUT>)
{
	chomp;
	@row = split(' ');
	$row[0] =~ s/\.tpf/\.iff/;
	$templates{$row[0]} = [$row[1]];
}

open( PLANET_INPUT, "planets_with_buildout.txt" ) || die $1;

while (<PLANET_INPUT>)
{
	chomp;
	$planet = $_;
	
	#
	# clear existing client files
	#
	
	for ( $i = 0; $i < 64; ++$i )
	{
		$file = "client/" . $planet . "_" . int( $i / 8 + 1 ) . "_" . ( $i % 8 + 1 ) . ".tab";
		print $file . "\n";
		open( OUTPUT, ">" . $file ) || die $!;
		print OUTPUT "objid\tcontainer\tshared_template_crc\tcell_index\tpx\tpy\tpz\tqw\tqx\tqy\tqz\tradius\tportal_layout_crc\n";
		print OUTPUT "i\ti\th\ti\tf\tf\tf\tf\tf\tf\tf\tf\ti\n";
		close OUTPUT;
		
		$file = "server/" . $planet . "_" . int( $i / 8 + 1 ) . "_" . ( $i % 8 + 1 ) . ".tab";
		print $file . "\n";
		open( OUTPUT, ">" . $file ) || die $!;
		print OUTPUT "objid\tcontainer\tserver_template_crc\tcell_index\tpx\tpy\tpz\tqw\tqx\tqy\tqz\tscripts\tobjvars\n";
		print OUTPUT "i\ti\th\ti\tf\tf\tf\tf\tf\tf\tf\ts\ts\n";
		close OUTPUT;
		
	}
}

	
#
# open the exported data
#

open( INPUT, "export.dat" ) || die "unable to open " . $planet . ".tab";
	
while (<INPUT>)
{
	chomp;
	($planet,$row) = /(\S+)\s(.*)/;
#		next if $planet ne $planet;
	
	($objid,$container,$typeid,$template,$cell,$x,$y,$z,$ow,$ox,$oy,$oz,$scripts,$objvars) = split(',',$row);
	
	$scripts =~ s/\s//g; # remove any spaces
	
	$ax = floor( ( $x + 8192 ) / 16384 * 8 ) + 1;
	$az = floor( ( $z + 8192 ) / 16384 * 8 ) + 1;
	
	#
	# compute new $x,$z
	#

	if ( !$container )
	{
		$x = _fmod( $x, 2048 );
		$z = _fmod( $z, 2048 );
	}
	
	print "$ax $az\n" if $x < -8192 || $z < -8192;
		
	$file = $planet . "_" . $ax . "_" . $az . ".tab";
	
	if ( !$container )
	{
		if ( $file ne $lastFile )
		{
			$lastFile = $file;
			open( SERVER, ">>server/" . $file ) || die $!;
			open( CLIENT, ">>client/" . $file ) || die $!;
			print $file . "\n";
		}
	}
	
	print SERVER "$objid\t$container\t$template\t$cell\t$x\t$y\t$z\t$ow\t$ox\t$oy\t$oz\t$scripts\t$objvars\n";
	
	## hack the row for the client
	## we're searching for this pattern: portalProperty.crc|0|-770742594
	($portal) = $objvars =~ /portalProperty\.crc\|0\|(-?\d+)/;
	$portal = 0 if !$portal;
		
#	if ( $templates{ $template } )
	{
		$radius = $templates{ $template }[0];

		# fix the template name for the client
		$template =~ s/\/([^\/]+)$/\/shared_$1/;
		
		print CLIENT "$objid\t$container\t$template\t$cell\t$x\t$y\t$z\t$ow\t$ox\t$oy\t$oz\t$radius\t$portal\n";
	}

}

	

