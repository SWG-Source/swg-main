#!/usr/bin/perl
use warnings;
use strict;

# =====================================================================

my @crctable =
(
	hex("0x00000000"), hex("0x04C11DB7"), hex("0x09823B6E"), hex("0x0D4326D9"), hex("0x130476DC"), hex("0x17C56B6B"), hex("0x1A864DB2"), hex("0x1E475005"),
	hex("0x2608EDB8"), hex("0x22C9F00F"), hex("0x2F8AD6D6"), hex("0x2B4BCB61"), hex("0x350C9B64"), hex("0x31CD86D3"), hex("0x3C8EA00A"), hex("0x384FBDBD"),
	hex("0x4C11DB70"), hex("0x48D0C6C7"), hex("0x4593E01E"), hex("0x4152FDA9"), hex("0x5F15ADAC"), hex("0x5BD4B01B"), hex("0x569796C2"), hex("0x52568B75"),
	hex("0x6A1936C8"), hex("0x6ED82B7F"), hex("0x639B0DA6"), hex("0x675A1011"), hex("0x791D4014"), hex("0x7DDC5DA3"), hex("0x709F7B7A"), hex("0x745E66CD"),
	hex("0x9823B6E0"), hex("0x9CE2AB57"), hex("0x91A18D8E"), hex("0x95609039"), hex("0x8B27C03C"), hex("0x8FE6DD8B"), hex("0x82A5FB52"), hex("0x8664E6E5"),
	hex("0xBE2B5B58"), hex("0xBAEA46EF"), hex("0xB7A96036"), hex("0xB3687D81"), hex("0xAD2F2D84"), hex("0xA9EE3033"), hex("0xA4AD16EA"), hex("0xA06C0B5D"),
	hex("0xD4326D90"), hex("0xD0F37027"), hex("0xDDB056FE"), hex("0xD9714B49"), hex("0xC7361B4C"), hex("0xC3F706FB"), hex("0xCEB42022"), hex("0xCA753D95"),
	hex("0xF23A8028"), hex("0xF6FB9D9F"), hex("0xFBB8BB46"), hex("0xFF79A6F1"), hex("0xE13EF6F4"), hex("0xE5FFEB43"), hex("0xE8BCCD9A"), hex("0xEC7DD02D"),
	hex("0x34867077"), hex("0x30476DC0"), hex("0x3D044B19"), hex("0x39C556AE"), hex("0x278206AB"), hex("0x23431B1C"), hex("0x2E003DC5"), hex("0x2AC12072"),
	hex("0x128E9DCF"), hex("0x164F8078"), hex("0x1B0CA6A1"), hex("0x1FCDBB16"), hex("0x018AEB13"), hex("0x054BF6A4"), hex("0x0808D07D"), hex("0x0CC9CDCA"),
	hex("0x7897AB07"), hex("0x7C56B6B0"), hex("0x71159069"), hex("0x75D48DDE"), hex("0x6B93DDDB"), hex("0x6F52C06C"), hex("0x6211E6B5"), hex("0x66D0FB02"),
	hex("0x5E9F46BF"), hex("0x5A5E5B08"), hex("0x571D7DD1"), hex("0x53DC6066"), hex("0x4D9B3063"), hex("0x495A2DD4"), hex("0x44190B0D"), hex("0x40D816BA"),
	hex("0xACA5C697"), hex("0xA864DB20"), hex("0xA527FDF9"), hex("0xA1E6E04E"), hex("0xBFA1B04B"), hex("0xBB60ADFC"), hex("0xB6238B25"), hex("0xB2E29692"),
	hex("0x8AAD2B2F"), hex("0x8E6C3698"), hex("0x832F1041"), hex("0x87EE0DF6"), hex("0x99A95DF3"), hex("0x9D684044"), hex("0x902B669D"), hex("0x94EA7B2A"),
	hex("0xE0B41DE7"), hex("0xE4750050"), hex("0xE9362689"), hex("0xEDF73B3E"), hex("0xF3B06B3B"), hex("0xF771768C"), hex("0xFA325055"), hex("0xFEF34DE2"),
	hex("0xC6BCF05F"), hex("0xC27DEDE8"), hex("0xCF3ECB31"), hex("0xCBFFD686"), hex("0xD5B88683"), hex("0xD1799B34"), hex("0xDC3ABDED"), hex("0xD8FBA05A"),
	hex("0x690CE0EE"), hex("0x6DCDFD59"), hex("0x608EDB80"), hex("0x644FC637"), hex("0x7A089632"), hex("0x7EC98B85"), hex("0x738AAD5C"), hex("0x774BB0EB"),
	hex("0x4F040D56"), hex("0x4BC510E1"), hex("0x46863638"), hex("0x42472B8F"), hex("0x5C007B8A"), hex("0x58C1663D"), hex("0x558240E4"), hex("0x51435D53"),
	hex("0x251D3B9E"), hex("0x21DC2629"), hex("0x2C9F00F0"), hex("0x285E1D47"), hex("0x36194D42"), hex("0x32D850F5"), hex("0x3F9B762C"), hex("0x3B5A6B9B"),
	hex("0x0315D626"), hex("0x07D4CB91"), hex("0x0A97ED48"), hex("0x0E56F0FF"), hex("0x1011A0FA"), hex("0x14D0BD4D"), hex("0x19939B94"), hex("0x1D528623"),
	hex("0xF12F560E"), hex("0xF5EE4BB9"), hex("0xF8AD6D60"), hex("0xFC6C70D7"), hex("0xE22B20D2"), hex("0xE6EA3D65"), hex("0xEBA91BBC"), hex("0xEF68060B"),
	hex("0xD727BBB6"), hex("0xD3E6A601"), hex("0xDEA580D8"), hex("0xDA649D6F"), hex("0xC423CD6A"), hex("0xC0E2D0DD"), hex("0xCDA1F604"), hex("0xC960EBB3"),
	hex("0xBD3E8D7E"), hex("0xB9FF90C9"), hex("0xB4BCB610"), hex("0xB07DABA7"), hex("0xAE3AFBA2"), hex("0xAAFBE615"), hex("0xA7B8C0CC"), hex("0xA379DD7B"),
	hex("0x9B3660C6"), hex("0x9FF77D71"), hex("0x92B45BA8"), hex("0x9675461F"), hex("0x8832161A"), hex("0x8CF30BAD"), hex("0x81B02D74"), hex("0x857130C3"),
	hex("0x5D8A9099"), hex("0x594B8D2E"), hex("0x5408ABF7"), hex("0x50C9B640"), hex("0x4E8EE645"), hex("0x4A4FFBF2"), hex("0x470CDD2B"), hex("0x43CDC09C"),
	hex("0x7B827D21"), hex("0x7F436096"), hex("0x7200464F"), hex("0x76C15BF8"), hex("0x68860BFD"), hex("0x6C47164A"), hex("0x61043093"), hex("0x65C52D24"),
	hex("0x119B4BE9"), hex("0x155A565E"), hex("0x18197087"), hex("0x1CD86D30"), hex("0x029F3D35"), hex("0x065E2082"), hex("0x0B1D065B"), hex("0x0FDC1BEC"),
	hex("0x3793A651"), hex("0x3352BBE6"), hex("0x3E119D3F"), hex("0x3AD08088"), hex("0x2497D08D"), hex("0x2056CD3A"), hex("0x2D15EBE3"), hex("0x29D4F654"),
	hex("0xC5A92679"), hex("0xC1683BCE"), hex("0xCC2B1D17"), hex("0xC8EA00A0"), hex("0xD6AD50A5"), hex("0xD26C4D12"), hex("0xDF2F6BCB"), hex("0xDBEE767C"),
	hex("0xE3A1CBC1"), hex("0xE760D676"), hex("0xEA23F0AF"), hex("0xEEE2ED18"), hex("0xF0A5BD1D"), hex("0xF464A0AA"), hex("0xF9278673"), hex("0xFDE69BC4"),
	hex("0x89B8FD09"), hex("0x8D79E0BE"), hex("0x803AC667"), hex("0x84FBDBD0"), hex("0x9ABC8BD5"), hex("0x9E7D9662"), hex("0x933EB0BB"), hex("0x97FFAD0C"),
	hex("0xAFB010B1"), hex("0xAB710D06"), hex("0xA6322BDF"), hex("0xA2F33668"), hex("0xBCB4666D"), hex("0xB8757BDA"), hex("0xB5365D03"), hex("0xB1F740B4")
);

my %crc;
my %offset;
my $offset = 0;

# =====================================================================

sub crc
{
	use integer;

	my $string = $_[0];
	return 0 if ($string eq "");

	my $crc_init = hex("0xffffffff") & 0xffffffff;
	my $crc = $crc_init;

	foreach (split(//, $string))
	{
		$crc = ($crctable[(($crc>>24) ^ ord($_)) & 255] ^ ($crc << 8) & 0xffffffff);
	}

	return $crc ^ $crc_init & 0xffffffff;
}


# =====================================================================

die "usage: buildCrcStringTable.pl [-t tabFileName.ext] outputFileName.ext [stringFile...]\n" .
	"-t : generate tab delimited output file as well\n" .
	"If the output file name extension is .mif, then the text mif file will be generated.\n" .
	"Otherwise, the binary IFF data will be written.\n" if (@ARGV < 1 || $ARGV[0] =~ /^[\/-][h\?]$/);

my $outputFileName = shift;
my $tab = 0;
my $tabFileName = "";

if ($outputFileName eq "-t")
{
	$tab = 1;
	$tabFileName = shift;
	$outputFileName = shift;
}

while (<>)
{
	chomp();

	if ($_ ne "")
	{
		my $crc = sprintf("0x%08x", crc($_));
		die "crc string clash for $crc:\n\t$crc{$crc}\n\t$_\n" if (defined($crc{$crc}) && $_ ne $crc{$crc});
		$crc{$crc} = $_;
	}
}

open(OUTPUT, "> tempfile") || die "could not open tempfile\n";
my $old = select(OUTPUT);

print "form \"CSTB\"\n";
print "{\n";
print "\tform \"0000\"\n";
print "\t{\n";
print "\t\tchunk \"DATA\"\n";
print "\t\t{\n";
print "\t\t\tint32 ", scalar(keys(%crc)), "\n";
print "\t\t}\n";
print "\n";
print "\t\tchunk \"CRCT\"\n";
print "\t\t{\n";

foreach (sort keys %crc)
{
	print "\t\t\tuint32 ", $_, "\n";
	$offset{$_} = $offset;
	$offset += length($crc{$_}) + 1;
}

print "\t\t}\n";
print "\n";
print "\t\tchunk \"STRT\"\n";
print "\t\t{\n";

foreach (sort keys %crc)
{
	print "\t\t\tint32 ", $offset{$_}, "\n";
}

print "\t\t}\n";
print "\n";
print "\t\tchunk \"STNG\"\n";
print "\t\t{\n";

foreach (sort keys %crc)
{
	print "\t\t\tcstring \"", $crc{$_}, "\" /* ", $_, " */\n";
}

print "\t\t}\n";
print "\t}\n";
print "}\n";

select $old;
close(OUTPUT);

if ($outputFileName =~ /\.mif/)
{
	rename("tempfile", $outputFileName);
}
else
{
	print $outputFileName, "\n";
	system("Miff -i tempfile -o $outputFileName");
	unlink("tempfile");
}

if ($tab)
{
	open(OUTPUT, ">" . $tabFileName) || die "could not open $tabFileName\n";

		foreach (sort keys %crc)
		{
			print OUTPUT $_, "\t", $crc{$_}, "\n";
		}

	close(OUTPUT);
}
