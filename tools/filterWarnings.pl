#!/usr/bin/perl

sub usage
{
}


sub numerically
{
        return -($a <=> $b);
}

while (<>)
{
        s/\s+/ /;

        chomp;

        foreach $compare (keys %warnings)
        {
         @current = split(/\s+/, $_);
         @compare = split(/\s+/, $compare);

         if (scalar(@current) == scalar(@compare))
         {
          $count = 0;
          $out = "";
          while (@current)
          {
           $a = shift @current;
           $b = shift @compare;

           if ($a eq $b)
           {
            $out .= " $a";
           }
           else
           {
            $out .= " XXXX";
            $count += 1;
           }
          }

          if ($count <= $similar)
          {
           $out =~ s/^ //;
           if ($warnings{$out} ne $warnings{$compare})
           {
            $warnings{$out} = $warnings{$compare};
            delete $warnings{$compare};
           }

           $_ = $out;
          }
          else
          {
          }
         }
        }

        $warnings{$_} += 1 if ($repeat == 0)
}


foreach (keys %warnings)
{
        push(@warnings, sprintf("%5d %s", $warnings{$_}, $_));
}

foreach (sort numerically @warnings)
{
        print $_, "\n";
}
