#
# note: this script will likely only run in a Win32 CMD.EXE console
#
# Use this script to generate the exported data, then use the divide.pl
# script to generate the individual buildout files for each planet.
#

use DBI;
use strict;

my $dbh = DBI->connect('DBI:Oracle:swodb','swodb_s7_gold','changeme') || die $!;

#
# one of these will select by planet, and the other
# will just dump everything
#

#my $sth1 = $dbh->prepare( "select OBJECT_ID from OBJECTS where DELETED = 0 and PLAYER_CONTROLLED = 'N' and CONTAINED_BY = 0 and SCENE_ID = 'naboo' order by SCENE_ID, floor( (x+8192)/16384*8) * 8 + floor( ( z + 8192 ) / 16384 * 8 )" );
my $sth1 = $dbh->prepare( "select OBJECT_ID from OBJECTS where DELETED = 0 and PLAYER_CONTROLLED = 'N' and CONTAINED_BY = 0 order by SCENE_ID, floor( (x+8192)/16384*8) * 8 + floor( ( z + 8192 ) / 16384 * 8 )" );


################


my $sth2 = $dbh->prepare( "select * from OBJECTS where DELETED = 0 start with OBJECT_ID = ? connect by prior OBJECT_ID = CONTAINED_BY" );
my $sth3 = $dbh->prepare( "select CELL_NUMBER from CELL_OBJECTS where OBJECT_ID = ? ");
my $sth4 = $dbh->prepare( "select NAME from OBJECT_TEMPLATES where ID = ?" );
my $sth5 = $dbh->prepare( "select name, type, value from object_variables inner join object_variable_names on name_id = id where object_id = ?" );

# select
#	 object_id,
#	 scene_id,
#	 x,
#	 y,
#	 z,
#	 floor( (x+8192)/16384*8) * 8 + floor( ( z + 8192 ) / 16384 * 8 ) as FOO
# from objects
# where deleted = 0 and contained_by = 0
# order by scene_id, FOO;

sub getObjVars
{
	my ( $data ) = @_;

	$sth5->execute( %$data->{'OBJECT_ID'} );
	
	my $objvar = "";
	my @objvars;
	
	while ( ( @objvars = $sth5->fetchrow_array() ) )
	{
		$objvar .= $objvars[0] . "|" . $objvars[1] . "|" . $objvars[2] . "|";
	}
	
	for ( my $i = 0; $i <= 19; ++$i )
	{
		my $fieldName_value = "OBJVAR_" . $i . "_VALUE";
		my $fieldName_type  = "OBJVAR_" . $i . "_TYPE";
		my $fieldName_name  = "OBJVAR_" . $i . "_NAME";
		
		if ( %$data->{$fieldName_name} )
		{
			$objvar .= %$data->{$fieldName_name} . "|" . %$data->{$fieldName_type} . "|" . %$data->{$fieldName_value} . "|";
		}
	
	}

	$objvar .= "\$|";

	return $objvar;
}

sub contains
{
	my $value = @_[0];
	my $array = @_[1];
	
	foreach my $item ( @$array )
	{
		return 1 if $item == $value;
	}
	
	return 0;
}

sub dumpObject
{
	my ( $data ) = @_;
	
	my $cell = 0;

	if ( %$data->{'CONTAINED_BY'} != 0 )
	{
		$sth3->execute( %$data->{'CONTAINED_BY'} );
		
		my $row = $sth3->fetchrow_arrayref();
		
		if ( $row )
		{
			$cell = %$row->[0];
		}
		else
		{
			$sth3->execute( %$data->{'OBJECT_ID'} );
			$row = $sth3->fetchrow_arrayref();
#			die "unable to find cell for object " . %$data->{'OBJECT_ID'} . "\n" if !$row;
			$cell = %$row->[0] if $row;
		}
	}

	#
	# determine my template name
	#
	
#	print %$data->{'OBJECT_TEMPLATE_ID'} . "\n";
	
	$sth4->execute( %$data->{'OBJECT_TEMPLATE_ID'} );
	my $template = ($sth4->fetchrow_arrayref())->[0];
	
	die "unable to find template name for template " . $template . "\n" if !$template;
	
	my $sharedTemplate = $template;
	$sharedTemplate =~ s/\/([^\/]+)$/\/shared_$1/;
#	print $template . " " . $sharedTemplate . "\n";
	
	#
	# get my objvars
	#
	
	my $objvars = getObjVars( $data );

	#
	# parse script list
	#
	
	my $scriptList = %$data->{'SCRIPT_LIST'};
	$scriptList =~ s/\:$//;

	#
	#
	#
		
	print %$data->{'SCENE_ID'} . " ";
	print %$data->{'OBJECT_ID'} . ",";
	print %$data->{'CONTAINED_BY'} . ",";
	print %$data->{'TYPE_ID'} . ",";
	print $template . ",";
	print $cell . ",";
	print %$data->{'X'} . ",";
	print %$data->{'Y'} . ",";
	print %$data->{'Z'} . ",";
	print %$data->{'QUATERNION_W'} . ",";
	print %$data->{'QUATERNION_X'} . ",";
	print %$data->{'QUATERNION_Y'} . ",";
	print %$data->{'QUATERNION_Z'} . ",";
	print $scriptList . ",";
	print $objvars;
	
	print "\n";
}

sub exportSingleObject
{
	my ( $objId ) = @_;
	
	$sth2->execute( $objId );
	
	my $data;
	
	while ( ( $data = $sth2->fetchrow_hashref() ) )
	{
		dumpObject( $data );
	}
	
}

sub export
{
	my @data1;
	my $counter = 0;
	
	$sth1->execute();
	
	while ( ( @data1 = $sth1->fetchrow_array() ) ) #&& ++$counter < 10 )
	{
		exportSingleObject( $data1[0] );
	}
}
	
export;
