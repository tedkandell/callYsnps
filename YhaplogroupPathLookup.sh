#/bin/bash

function usage()
{
    >&2 echo "usage: YhaplogroupPathLookup.sh [-h|--help] [haplogroup name]"
}

INSTALL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

PathLookupTable=${INSTALL_DIR}/tree/haplogroupPathLookupTable.tsv

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

if [ ! -f ${PathLookupTable} ]
then

   >&2 echo "cannot open haplogroup path lookup table: ${PathLookupTable}"
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

awk -v PathLookupTable=$PathLookupTable -v haplogroup="${haplogroup}" '
BEGIN {
   FS=OFS="\t"; 

   while (( getline line < PathLookupTable) > 0 ) 
   {
      split(line, fields)
      pathLookup[fields[1]] = fields[2]
   }

   close(PathLookupTable)

   print pathLookup[haplogroup]
} 

'

