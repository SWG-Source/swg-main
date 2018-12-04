#/bin/bash

DIR="$( dirname "${BASH_SOURCE[0]}" )"
WDIR="$(pwd)" #working dir (normally /home/swg/swg-main )

destination="data/sku.0/sys.server/compiled/game"
sourcepath="dsrc/sku.0/sys.server/compiled/game"

mkdir -p $destination/script

filenames=$(find $sourcepath -name '*.java')
spinstr='|/-\'
i=0
current=0
total=$(ls ${filenames[@]} | wc -l)

declare -A items=() #this holds all of the scriptlib const things that need recompilation

for filename in $filenames; do
    OFILENAME=${filename/$sourcepath/$destination}
    OFILENAME=${OFILENAME/java/class}

    if [[ -e $OFILENAME && $filename -nt $OFILENAME ]] || [ ! -e $OFILENAME ]; then
	   result=$(${DIR}/build_java_single.sh $filename 2>&1)
	   while read -r l; do
	      l=${l/"public static final "/""}
	      #echo "l is $l" #debug
	      l=$(echo $l | tr -s ' ' | cut -d ' ' -f 2) #grab field 2 (TYPE NAME =)
	      echo "got const? $l" #debug
	      cd $WDIR/dsrc/sku.0/sys.server/compiled/game/script #cd to scripts, for grep of $k
	      while read -r k; do
	         echo "got other? $k" #debug
	         items[$k]=1 #add $k to our list to compile (at the end of the script)
	      done < <(grep -Rinwl . -e $l) #find all scripts using the variable "$l"
	      cd $WDIR #cd back to working directory after grep
	   done < <(git --git-dir=$WDIR/dsrc/.git --work-tree=$WDIR/dsrc diff origin/master -U0 | grep -o "public static final .*=") #find all 'public static final' declarations in our changed scripts vs origin/master
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

for item in "${!items[@]}"; do
    item=${item//"./"/}
    echo "library CONST - recompiling $item"
    $WDIR/utils/build_java_single.sh $WDIR/dsrc/sku.0/sys.server/compiled/game/script/$item
done

echo ""
