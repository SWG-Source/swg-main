#!/usr/bin/perl

#2607

sub numerically { $a <=> $b }

die "usage: p4FindUnchanged.pl changelistSpec [changelistSpec ...]\nA changelistSpec is either a single changelist or a range specified as begin..end\n" if (scalar(@ARGV) == 0);
eval "\@changes = sort numerically " . join(",", @ARGV);

foreach $change (@changes)
{
	print STDERR "scanning changelist $change\n";

	open(P4, "p4 describe -s $change |");
	@describe = <P4>;
	close(P4);

	$_ = shift @describe;

	if (/\*pending\*/)
	{
		next;
	}
	
	$user = (split(/[\s\@]+/))[3];
	foreach $file (@describe)
	{
		if ($file =~ s/^\.\.\.\s+//)
		{
			next if ($file !~ m#//depot/swg/current/#);
			
			($file, $version, $type) = split(/[#\s]+/, $file);
			
			if ($version > 1 && $type ne "delete")
			{
				$old = $version - 1;
				open(P4, "p4 diff2 -q -t $file#$version $file#$old |");
				@diffs = <P4>;
				if (!@diffs)
				{
					print "$user $file#$version\n";
				}
				
				close(P4);
			}
		}
	}
}
