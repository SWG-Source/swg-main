# ======================================================================
# PortalAppearanceTemplate.pm
# Copyright 2003, Sony Online Entertainment
# All rights reserved.
# ======================================================================

package PortalAppearanceTemplate;
use strict;

use CustomizationVariableCollector;
use Iff;

# ======================================================================
# PortalAppearanceTemplate potentially-public variables.
# ======================================================================

# our $relativePathName;

# ======================================================================
# Setup variables that can be imported by Exporter into user modules.
# ======================================================================

use vars qw(@ISA @EXPORT_OK $VERSION);
use Exporter;
$VERSION = 1.00;
@ISA	 = qw(Exporter);

# These symbols are okay to export if specifically requested.
@EXPORT_OK = qw(&install);

# ======================================================================
# PortalAppearanceTemplate private variables.
# ======================================================================

my $debug = 0;
my $treeFileRelativeName;
my $treeFileFullName;

# ======================================================================
# PortalAppearanceTemplate public functions.
# ======================================================================

sub install
{
	# Register handler with CustomizationVariableCollector
	CustomizationVariableCollector::registerHandler("PRTO", \&processIff);
}

# ======================================================================
# PortalAppearanceTemplate private functions
# ======================================================================

sub processIff
{
	# Process args.
	my $iff = shift;
	die "bad iff arg specified" if ref($iff) ne "Iff";

	$treeFileRelativeName = shift;
	die "bad tree file relative name" if !defined($treeFileRelativeName);
	
	# We ignore any POBs that are not in sku.1 because we don't want to generate customization data 
	# for old POBs.
	$treeFileFullName = shift;
	if(!($treeFileFullName =~ /sku\.1/) && !($treeFileFullName =~ /_hue\.pob/) )
	{
		return 1;
	}

	# Ensure we're in the proper form.
	return 0 unless $iff->getCurrentName() eq "PRTO";
	
	$iff->enterForm("PRTO");
	{
		my $version = $iff->getCurrentName();
		if ($version eq '0004')
		{
			process_0004($iff);
		}
		else
		{
			print STDERR "PortalAppearanceTemplate: unsupported version tag [$version].\n";
			return 0;
		}
	}
	$iff->exitForm("PRTO");

	
	# Success.
	return 1;
}

# ----------------------------------------------------------------------

sub process_0004
{
	
	my $iff = shift;
	die 'bad $iff arg' if ref($iff) ne 'Iff';
	
	$iff->enterForm();
	
	$iff->enterChunk('DATA');
	$iff->exitChunk('DATA');
	$iff->enterForm('PRTS');
	$iff->exitForm('PRTS');
		
	$iff->enterForm('CELS');
	$iff->enterForm('CELL');
	
	my $sversion = $iff->getCurrentName();
	if ($sversion eq '0005')
	{
		process_0004_0005($iff);
	}
	else
	{
		print STDERR "PortalAppearanceTemplate: unsupported sub version tag [$sversion].\n";
		return 0;
	}
	
	$iff->exitForm('CELL');
	$iff->exitForm('CELS');
	$iff->exitForm();
	
}

# ----------------------------------------------------------------------

sub process_0004_0005
{
	
	my $iff = shift;
	die 'bad $iff arg' if ref($iff) ne 'Iff';

	$iff->enterForm();
	$iff->enterChunk('DATA');
	
	$iff->skipBytes(8);
	
	my $PortalAppearanceTemplateName = $iff->read_string();
	CustomizationVariableCollector::logAssetLink($treeFileRelativeName, $PortalAppearanceTemplateName);

	$iff->exitChunk('DATA');
	$iff->exitForm();
}	

# ======================================================================

1;
