# ======================================================================
# AppearanceTemplate.pm
# Copyright 2003, Sony Online Entertainment
# All rights reserved.
# ======================================================================

package AppearanceTemplate;
use strict;

use CustomizationVariableCollector;
use Iff;

# ======================================================================
# AppearanceTemplate potentially-public variables.
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
# AppearanceTemplate private variables.
# ======================================================================

my $debug = 0;
my $treeFileRelativeName;

# ======================================================================
# AppearanceTemplate public functions.
# ======================================================================

sub install
{
	# Register handler with CustomizationVariableCollector
	CustomizationVariableCollector::registerHandler("APT ", \&processIff);
}

# ======================================================================
# AppearanceTemplate private functions
# ======================================================================

sub processIff
{
	# Process args.
	my $iff = shift;
	die "bad iff arg specified" if ref($iff) ne "Iff";

	$treeFileRelativeName = shift;
	die "bad tree file relative name" if !defined($treeFileRelativeName);
	print "AppearanceTemplate: processing file [$treeFileRelativeName]\n" if $debug;

	# Ensure we're in the proper form.
	return 0 unless $iff->getCurrentName() eq "APT ";

	$iff->enterForm("APT ");
	{
		my $version = $iff->getCurrentName();
		if ($version eq '0000')
		{
			process_0000($iff);
		}
		else
		{
			print STDERR "AppearanceTemplate: unsupported version tag [$version].";
			return 0;
		}
	}
	$iff->exitForm("APT ");

	print "AppearanceTemplate: finished processing file [$treeFileRelativeName]\n" if $debug;

	# Success.
	return 1;
}

# ----------------------------------------------------------------------

sub process_0000
{
	print "process_0000(): begin\n" if $debug;

	my $iff = shift;
	die 'bad $iff arg' if ref($iff) ne 'Iff';

	$iff->enterForm('0000');
	$iff->enterChunk('NAME');

	my $appearanceTemplateName = $iff->read_string();
	CustomizationVariableCollector::logAssetLink($treeFileRelativeName, $appearanceTemplateName);
	
	$iff->exitChunk('NAME');
	$iff->exitForm('0000');

	print "process_0000(): end\n" if $debug;
}

# ======================================================================

1;
