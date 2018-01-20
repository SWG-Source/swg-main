#/bin/bash

DIR="$( dirname "${BASH_SOURCE[0]}" )"

destination="data/sku.0/sys.server/compiled/game"
sourcepath="dsrc/sku.0/sys.server/compiled/game"

mkdir -p $destination/script

filenames=$(find $sourcepath -name '*.java')
spinstr='|/-\'
i=0
current=0
total=$(ls ${filenames[@]} | wc -l)

for filename in $filenames; do
    OFILENAME=${filename/$sourcepath/$destination}
    OFILENAME=${OFILENAME/java/class}

    if [[ -e $OFILENAME && $filename -nt $OFILENAME ]] || [ ! -e $OFILENAME ]; then
	   result=$(${DIR}/build_java_single.sh $filename 2>&1)
    fi

    if [[ ! -z $result ]]; then
        printf "\r$filename\n"
        printf "$result\n\n"
    fi

    current=$((current+1))
    i=$(( (i+1) %4 ))
    perc=$(bc -l <<< "scale=0; $current*100/$total")
    printf "\rCompiling java scripts: [${spinstr:$i:1}] $perc%%"
done

echo ""
