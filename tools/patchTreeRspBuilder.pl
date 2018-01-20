#! /usr/bin/perl

die "usage: perl buildPatchTreeRsp.pl <old_digest> <new_digest> <patch_tree_rsp_base_without_rsp_extension> \n" if (scalar(@ARGV) != 3 || $ARGV[0] eq "-h" || $ARGV[0] eq "-?");

open(DIGEST, shift)  || die "could not open old digest\n";
	@old = <DIGEST>;
close(DIGEST);

open(DIGEST, shift) || die "could not open new digest\n";
	@new = <DIGEST>;
close(DIGEST);

$patchRsp = shift;
open(RSP_C, ">" . $patchRsp . "_c.rsp") || die "could not open output patch tree compressed rsp\n";
open(RSP_U, ">" . $patchRsp . "_u.rsp") || die "could not open output patch tree uncompressed rsp\n";

	while (@old && @new)
	{
		($oldName, $oldPath, $oldSize, $oldTime, $oldDigest) = split(/\s+/, $old[0]);
		($newName, $newPath, $newSize, $newTime, $newDigest) = split(/\s+/, $new[0]);

		$fileHandle = "RSP_C";
		$fileHandle = "RSP_U" if ($newName =~ /\.wav/ || $newName =~ /\.mp3/);

		if ($oldName eq $newName)
		{
			print $fileHandle "$newName @ $newPath/$newName\n" if ($oldSize != $newSize || $oldDigest ne $newDigest);
			shift @old;
			shift @new;
		}
		elsif ($oldName lt $newName)
		{
			print $fileHandle "$oldName @ deleted\n";
			shift @old;
		}
		else
		{
			print $fileHandle "$newName @ $newPath/$newName\n";
			shift @new;
		}
	}

	while (@old)
	{
		($oldName, $oldPath, $oldSize, $oldTime, $oldDigest) = split(/\s+/, $old[0]);

		$fileHandle = "RSP_C";
		$fileHandle = "RSP_U" if ($newName =~ /\.wav/ || $newName =~ /\.mp3/);

		print $fileHandle "$oldName @ deleted\n";
		shift @old;
	}

	while (@new)
	{
		($newName, $newPath, $newSize, $newTime, $newDigest) = split(/\s+/, $new[0]);

		$fileHandle = "RSP_C";
		$fileHandle = "RSP_U" if ($newName =~ /\.wav/ || $newName =~ /\.mp3/);

		print $fileHandle "$newName @ $newPath/$newName\n";
		shift @new;
	}

close(RSP_C);
close(RSP_U);
