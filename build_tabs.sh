#!/bin/bash

server=$(find ./dsrc/sku.0/sys.server/compiled/game/datatables -name '*.tab')
inc=$(find ./dsrc/sku.0/sys.shared/compiled/game/datatables/include -name '*.tab')
shared=$(find ./dsrc/sku.0/sys.shared/compiled/game/datatables -name '*.tab')

filenames=("${server[@]}" "${inc[@]}" "${shared[@]}")

spinstr='|/-\'
i=0
current=0
total=$(ls ${filenames[@]} | wc -l)

compile () {
        ofilename=${filename/dsrc/data}
        ofilename=${ofilename/.tab/.iff}
        mkdir -p $(dirname $ofilename)

        [ -e $ofilename ] && rm "$ofilename"

        result=$(./exe/linux/bin/DataTableTool -i "$filename" -- -s SharedFile searchPath10=data/sku.0/sys.shared/compiled/game searchPath10=data/sku.0/sys.server/compiled/game 2>&1)

        if [[ ! $result =~ .*SUCCESS.* ]]; then
                printf "\r$filename\n"
                printf "$result\n\n"
        fi
}

for filename in ${filenames[@]}; do
     current=$((current+1))
     i=$(( (i+1) %4 ))
     perc=$(bc -l <<< "scale=0; $current*100/$total")
     printf "\rGenerating Datatables: [${spinstr:$i:1}] $perc%%"
	while [ `jobs | wc -l` -ge 12 ]
        do
                sleep 5
        done
    compile $filename & done
wait

echo ""
