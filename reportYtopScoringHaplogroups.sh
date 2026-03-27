#!/bin/bash

function usage()
{
    >&2 echo "usage: reportYtopScoringHaplogroups.sh [-h|--help] [--top integer number of top scores of haplogroups to list (default 10)] [Y haplogroup summary file | stdin (default)]"
}

INSTALL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

PathLookupTable=${INSTALL_DIR}/tree/haplogroupPathLookupTable.tsv

top=5

while [ "$1" != "" ]; do
   case $1 in
        -h|-\?|--help)   # Call a "show_help" function to display a synopsis, then exit.
            usage
            exit
            ;;
        --top) # number of top scoring haplogroups to show in descendning order
            top=$2
            if [[ "$top" =~ ^[0-9]+$ ]] && (( $top > 0 ))
            then
               shift
            else
               usage
               exit 1
            fi
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            usage
            exit 1
            ;;
        *)
            break
   esac
   shift
done

input="-"

if [ -f "$1" ] #&& [ "${1: -4}" == ".tsv" ]
then
   input="${1}"
else if [ "${1}" != "" ]
     then
        >&2 echo "cannot open ${1}" # or it is not a valid .tsv file."
         usage
        exit 1
     fi
fi

tmp=$(mktemp)
cat "${input:--}" > "$tmp"

grep '^#Sample age' "$tmp"
grep -v "^#" "$tmp" | sort -n -r -k 4,4 | awk -v PathLookupTable=$PathLookupTable -v top=$top  '
BEGIN {
   FS=OFS="\t"; 

   while (( getline line < PathLookupTable) > 0 ) 
   {
      split(line, fields)
      pathLookup[fields[1]] = fields[2]
   }

   topScore = length(pathLookup)+1
   count = 0

   print "#State\tDerived SNPs/Total SNPs\tpotential aDNA damage\tScore\tHaplogroup path"
}

{
   if ($4 < topScore) 
   {
      topScore = $4 
      count++
   }

   split($5, haplogroups, ">")
   print $1, $2, $3, $4, pathLookup[haplogroups[length(haplogroups)]]

   if (count == top)
   {
      exit
   }
}

END {
  while (getline)
  {
     if ($4 == topScore)
     {
        split($5, haplogroups, ">")
        print $1, $2, $3, $4, pathLookup[haplogroups[length(haplogroups)]]
     }
     else
     {
        exit
     }
  }
}
'
rm "$tmp"
