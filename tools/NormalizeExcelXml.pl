#!/usr/bin/perl -i
use XML::Parser::PerlSAX;

die "usage: NormalizeExcelXml.pl <filename>\n" unless (@ARGV == 1);

$filename = $ARGV[0];

die "$filename not found\n" unless (-e $filename);
die "$filename not writable\n" unless (-w $filename);

$backup = $filename . "~";

die "Could not rename $filename -> $backup\n" unless (rename ($filename, $backup));


open (INFILE, "<$backup");
open (OUTFILE, ">$filename");

select(OUTFILE);


my $handler = MyHandler->new();
my $parser = XML::Parser::PerlSAX->new( Handler => $handler );


print "<?xml version=\"1.0\"?>";
$parser->parse(Source => { ByteStream => \*INFILE });



package MyHandler;


sub new {
		my ($type) = @_;
		my $self = {};
		
		$quiet_level = 0;
		$opened = 0;
		$indent_level = "";
		$open_tag = "";
		
		$in_cell = 0;

		%bad_elements = 
		( 
						"NamedCell", 1, 
						"Styles", 1,
		);

		%bad_attributes = 
		( 
						"ss:StyleID", 1, 
						"ss:AutoFitWidth", 1,
		);
		
		return bless ($self, $type);
}

sub start_element 
{
		my ($self, $element) = @_;
		my $name = $element->{Name};
		
		if (exists $bad_elements{$name})
		{
			$quiet_level += 1;	
		}
		
		if ($quiet_level == 0)
		{
			if (!$open_tag eq "")
			{
				print ">";
			}
			
			if (! $in_cell )
			{
				print "\n$indent_level";
			}
			
			print "<$name";
			
			foreach $z (keys %{$element->{Attributes}})
			{
				if (!exists $bad_attributes{$z})
				{
					
					print " " . $z . '="';
					
					$_ = $element->{Attributes}->{$z};
					
					s/\"/&quot;/g;
					s/</&lt;/g;
					s/>/&gt;/g;
					
					print $_;
					
					print '"';
					
				}
			}
			
			$open_tag = $name;
			
			#$indent_level = $indent_level . ' ';
			$opened = 1;
			
			if ($name eq "Cell")
			{
				$in_cell = 1;
			}
		}
}


sub end_element {
		my ($self, $element) = @_;
		my $name = $element->{Name};

		if ($quiet_level == 0)
		{
			#chop $indent_level;
			
			if ($open_tag eq $name)
			{
				print "/>";
			}
			else
			{
				if (!$opened && !$in_cell) 
				{ 
					print "\n$indent_level"; 
				}

				print "</$name>";
			}
			
			$open_tag = "";
			$opened = 0;
		}

		if ($name eq "Cell")
		{
			$in_cell = 0;
		}
		
		if (exists $bad_elements{$name})
		{
			$quiet_level -= 1;	
		}
}

sub characters {
		my ($self, $characters) = @_;
		
		$_ = $characters->{Data};
		chomp;

		if (/\S/) 
		{
			s/\"/&quot;/g;
			s/</&lt;/g;
			s/>/&gt;/g;

			if (!$open_tag eq "")
			{
				print ">";
				$open_tag = "";
			}
			
			print $_;
		}
}
