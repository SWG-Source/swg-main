#!/bin/bash

filenames=$(find ./dsrc -name '*.mif')
spinstr='|/-\'
i=0
current=0
total=$(ls ${filenames[@]} | wc -l)

for filename in $filenames; do
	ofilename=${filename/dsrc/data}
	ofilename=${ofilename/.mif/.iff}
	mkdir -p $(dirname $ofilename)

    if [[ -e $ofilename && $filename -nt $ofilename ]] || [ ! -e $ofilename ]; then
        result=$(./exe/linux/bin/Miff -i "$filename" -o "$ofilename" 2>&1)

        if [[ ! "$result" =~ .*successfully.* ]]; then
        	printf "\r$result\n\n"
        fi
    fi

    current=$((current+1))
    i=$(( (i+1) %4 ))
    perc=$(bc -l <<< "scale=0; $current*100/$total")
    printf "\rGenerating IFFs: [${spinstr:$i:1}] $perc%%"
done

echo ""
