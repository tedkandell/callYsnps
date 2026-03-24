#/bin/bash

function usage()
{
    >&2 echo "usage: YhaplogroupTMRCALookup.sh [-h|--help] [haplogroup name]"
}

INSTALL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

TMRCALookupTable=${INSTALL_DIR}/tree/haplogroupTMRCAtable.tsv

input="-"

while [ "$1" != "" ]; do
   case $1 in
        -h|-\?|--help)   # Call a "show_help" function to display a synopsis, then exit.
            usage
            exit
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            ;;
        *)
            break
   esac
   shift
done

input="-"

if [ ! -f ${TMRCALookupTable} ]
then

   >&2 echo "cannot open haplogroup TMRCA lookup table: ${TMRCALookupTable}"
   usage
   exit 1
fi

if [ "$1" != "" ]
then
   haplogroup="${1}"
else
   >&2 echo "no haplogroup given"
   usage
   exit 1
fi

awk -v TMRCALookupTable=$TMRCALookupTable -v haplogroup="${haplogroup}" '
BEGIN {
   FS=OFS="\t"; 

   while (( getline line < TMRCALookupTable) > 0 ) 
   {
      split(line, fields)
      TMRCALookup[fields[1]] = fields[2]
   }

   close(TMRCALookupTable)

   print haplogroup, TMRCALookup[haplogroup]
} 

'

