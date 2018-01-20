#!/bin/bash

filenames=$(find ./dsrc -name '*.tpf')
spinstr='|/-\'
i=0
current=0
total=$(find ./dsrc -name '*.tpf' | wc -l)

compile () {
        ofilename=${filename/dsrc/data}
        ofilename=${ofilename/.tpf/.iff}
        mkdir -p $(dirname $ofilename)

    if [[ -e $ofilename && $filename -nt $ofilename ]] || [ ! -e $ofilename ]; then
        result=$(./exe/linux/bin/TemplateCompiler -compile "$filename" 2>&1)

        if [[ ! -z $result ]]; then
                printf "\r$filename\n"
            printf "$result\n\n"
        fi
    fi
}

for filename in $filenames; do
    current=$((current+1))
    i=$(( (i+1) %4 ))
    perc=$(bc -l <<< "scale=0; $current*100/$total")
    printf "\rGenerating Object Templates: [${spinstr:$i:1}] $perc%%"
	while [ `jobs | wc -l` -ge 50 ]
        do
                sleep 5
        done
    compile $filename & done
wait

echo ""
