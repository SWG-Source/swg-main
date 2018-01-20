#!/usr/bin/perl

use strict;
use warnings;
use perllib::Iff;

#	Things to look for: 
#
#	object templates 
#		forceNoCollision
#
#	appearance templtaes
#		FORM 0003
#			Extents
#			NULL collision extent means not collideable
#			1163416400 - EXSP
#			1163412056 - EXBX
#			1480808780 - XCYL
#			1129140308 - CMPT
#			1146372428 - DTAL
#			1129141064 - CMSH
#			1314212940 - NULL
#
#	Path:
#		objectTemplate (probably have to go up heirarchy / shared)
#			- scan for forceNoCollision
#			- scan for appearanceTemplate (server side)
#		appearanceTemplate
#			- scan for ssa
#		serverSideAppearance
#			- scan for collision extent

use constant DEBUG              => 1;

use constant UNTESTED           => -1;
use constant NOT_COLLIDEABLE    => 0;
use constant COLLIDEABLE        => 1;

sub usage
{
	die "\n\tfindAllCollideableObjects.pl <branch>\n\n";
}

usage if (!@ARGV);

my $branch = shift;

my $branchDir = "";
open (P4, "p4 -ztag where //depot/swg/$branch/... |") || die "Can't run p4 where for $branch\n";
while (<P4>)
{
	$branchDir = $1 if (m!\.\.\. path (\S+)[\\\/]\.\.\.!);
}
close (P4);

$branchDir =~ s![\\\/]+!/!g;

my %appearanceTemplates;
my %objectTemplates;

print "\nBuilding list of all object templates...\n";
open (P4, "p4 files //depot/swg/$branch/dsrc/*/sys.s*/compiled/game/object/... |") || die "Can't run p4 files for $branch\n";
while (<P4>)
{
	next if (/ - delete/);
	
	chomp;
	s!\#.*$!!;
	
	# element maps to : [ <absolute path>, <collideable> ]
	my $path = $_;
	$path =~ s!//depot/swg/$branch/!$branchDir/!;
	$_ =~ s!^.*/dsrc/sku[^\\\/]+/sys[^\\\/]+/compiled/game/!!;

	$objectTemplates{$_} = [$path, UNTESTED];
}
close (P4);

print "\nBuilding list of all appearance files...\n";
open (P4, "p4 files //depot/swg/$branch/data/*/sys.*/.../appearance/... |") || die "Can't run p4 files for $branch\n";
while (<P4>)
{
	next if (/ - delete/);
	
	chomp;
	s!\#.*$!!;
	
	my $path = $_;
	$path =~ s!//depot/swg/$branch/!$branchDir/!;
	$_ =~ s!^.*/data/sku[^\\\/]+/sys[^\\\/]+/[^\\\/]+/[^\\\/]+/!!;
	
	$appearanceTemplates{$_} = [$path, UNTESTED];
}
close (P4);

print "\nScanning all object templates...\n";
foreach my $objectTemplate (sort keys %objectTemplates)
{
	# skip this element if we've tested it
	next if ($objectTemplates{$objectTemplate}->[1] != UNTESTED);
	
	if ($objectTemplate =~ m!/base/! || $objectTemplate =~ m!/base/!)
	{
		print "$objectTemplate : not collideable : because it's a base object\n" if (DEBUG);
		$objectTemplates{$objectTemplate}->[1] = NOT_COLLIDEABLE;
		next;
	}

	if ($objectTemplate =~ m!\.(btm)|(me)|(txt)!)
	{
		print "$objectTemplate : not collideable : because it's a file I don't care about\n" if (DEBUG);
		$objectTemplates{$objectTemplate}->[1] = NOT_COLLIDEABLE;
		next;
	}

	my $collideable = UNTESTED;
	my $analyzingObjectTemplate = $objectTemplate;
	my $debugTabs = "";
	
	while ($collideable == UNTESTED)
	{
		my $forceNoCollision = 0;
		my $appearanceTemplate = "";
		my $baseObjectTemplate = "";
		my $sharedObjectTemplate = "";
		my $portalLayoutFile = "";

 		if (DEBUG)
 		{
			print "${debugTabs}Scanning $analyzingObjectTemplate...\n";
			$debugTabs .= "\t";
		}
	
		my $analyzingObjectTemplateDisk = $objectTemplates{$analyzingObjectTemplate}->[0];
		open (OT, $analyzingObjectTemplateDisk) || die "Can't open $analyzingObjectTemplateDisk\n";
		while (<OT>)
		{
			$baseObjectTemplate = $1 if (m/^\s*\@base\s+(\S+)/i);
			$forceNoCollision = 1 if (m/^\s*forceNoCollision\s*=\s*true/i);
			$appearanceTemplate = $1 if (m/^\s*appearanceFilename\s*=\s*\"(\S+)\"/i);
			$sharedObjectTemplate = $1 if (m/^\s*(?:crafted)?sharedTemplate\s*=\s*\"(\S+)\"/i);
			$portalLayoutFile = $1 if (m/^\s*portalLayoutFilename\s*=\s*\"(\S+)\"/i);
		}
		close (OT);

		if ($forceNoCollision)
		{
			print "$objectTemplate : not collideable : forceNoCollision specified\n" if (DEBUG);
			$collideable = NOT_COLLIDEABLE;
			last;
		}
		
		if ($portalLayoutFile)
		{
			print "$objectTemplate : collideable : portal layout found\n" if (DEBUG);
			$collideable = COLLIDEABLE;
			last;
		}
		
		if ($appearanceTemplate)
		{
			my $appearanceTemplateDisk = (exists $appearanceTemplates{$appearanceTemplate}) ? $appearanceTemplates{$appearanceTemplate}->[0] : "";

			if ($appearanceTemplateDisk =~ m!/sys\.client/!)
			{
				print "$objectTemplate : not collideable : appearance is client side only\n" if (DEBUG);
				$collideable = NOT_COLLIDEABLE;	
				last;
			}
			else
			{
				print "${debugTabs}Scanning appearance $appearanceTemplate...\n" if (DEBUG);
				if ($appearanceTemplateDisk)
				{
					my $appearanceFileHandle;
					open ($appearanceFileHandle, $appearanceTemplateDisk) || die "Can't open $appearanceTemplateDisk\n";
					my $iff = Iff->createFromFileHandle($appearanceFileHandle);
					close ($appearanceFileHandle);

					# Handle Iff contents.
					my $name = $iff->getCurrentName();
					if ($name eq "APT " && $iff->isCurrentForm())
					{
						$iff->enterForm();

						$name = $iff->getCurrentName();
						if ($name eq "0000" && $iff->isCurrentForm())
						{
							$iff->enterForm();

							$name = $iff->getCurrentName();

							if ($name eq "NAME" && !$iff->isCurrentForm())
							{
								$iff->enterChunk();

								my $ssaFileName = $iff->read_string();
								print "${debugTabs}Scanning ssa $ssaFileName...\n" if (DEBUG);
								my $ssaFileNameDisk = (exists $appearanceTemplates{$ssaFileName}) ? $appearanceTemplates{$ssaFileName}->[0] : "";
								if ($ssaFileNameDisk)
								{
									my $ssaFileHandle;
									open ($ssaFileHandle, $ssaFileNameDisk) || die "Can't open $ssaFileNameDisk\n";
									$iff = Iff->createFromFileHandle($ssaFileHandle);
									close ($ssaFileHandle);

									# Handle Iff contents
									my $name = $iff->getCurrentName();
									if ($name eq "APPR" && $iff->isCurrentForm())
									{
										$iff->enterForm();

										$name = $iff->getCurrentName();
										if ($name eq "0003" && $iff->isCurrentForm())
										{
											$iff->enterForm();

											# enter / exit past extent block
											$iff->enterForm();
											$iff->exitForm();

											# we should now be pointing to the collision property form
											$name = $iff->getCurrentName();

											if ($name eq "NULL")
											{
												# enter / exit past collision property block
												$iff->enterForm();
												$iff->exitForm();

												# enter / exit past hardpoint block
												$iff->enterForm();
												$iff->exitForm();

												$name = $iff->getCurrentName();

												if ($name eq "FLOR" && $iff->isCurrentForm())
												{
													$iff->enterForm();

													$name = $iff->getCurrentName();
													if ($name eq "DATA" && !$iff->isCurrentForm())
													{
														$iff->enterChunk();

														my $hasFloor = $iff->read_uint8();

														if ($hasFloor == 0)
														{
															print "$objectTemplate : not collideable : null collision property and null floor\n" if (DEBUG);
															$collideable = NOT_COLLIDEABLE;	
														}
														else
														{
															print "$objectTemplate : collideable : non-null floor\n" if (DEBUG);
															$collideable = COLLIDEABLE;	
														}
													}
												}
											}
											else
											{
												print "$objectTemplate : collideable : non-null collision property\n" if (DEBUG);
												$collideable = COLLIDEABLE;	
											}
										}
										else
										{
											# for all other forms of this piece of data, we assume not collideable
											print "$objectTemplate : not collideable : null collision property\n" if (DEBUG);
											$collideable = NOT_COLLIDEABLE;
										}
									}								
								}
							}
						}					
					}

					# if we got here and didn't get a solution, default to collideable
					if ($collideable == UNTESTED)
					{
						print "$objectTemplate : collideable : couldn't get appearance template info\n" if (DEBUG);
						$collideable = COLLIDEABLE;	
						last;
					}
				}
			}
		}
		
		$sharedObjectTemplate =~ s!\.iff!\.tpf!;
		$baseObjectTemplate =~ s!\.iff!\.tpf!;

		if (!$sharedObjectTemplate || !exists $objectTemplates{$sharedObjectTemplate})
		{
			if (!$baseObjectTemplate || !exists $objectTemplates{$baseObjectTemplate})
			{
				print "$objectTemplate : collideable : no base, no shared, no appearance specified, defaulting\n" if (DEBUG);
				$collideable = COLLIDEABLE;
				last;
			}
			else
			{
				$sharedObjectTemplate = "";
			}
		}
		
		$analyzingObjectTemplate = ($sharedObjectTemplate) ? $sharedObjectTemplate : $baseObjectTemplate;
	}
	
	$objectTemplates{$objectTemplate}->[1] = $collideable;	
}

print "\nPrinting out object templates with collision...\n";
foreach my $template (sort keys %objectTemplates)
{
	print "$template\n" if ($objectTemplates{$template}->[1] == COLLIDEABLE && $template !~ /shared_/);
}