#/bin/bash

function usage()
{
    >&2 echo "usage: reportNovelYsnps [-h|--help] [--depth <integer> (default 2)]" 
    >&2 echo "[--percentDerived <float> (default 1)]"
    >&2 echo "[--minimumQUAL minimum QUAL score for a variant likelihood in the VCF (default 20 = 99% probability of a variant)]"
    >&2 echo "[.vcf.gz file | stdin (default)]"
}

INSTALL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

input="-"

depth=2
percentDerived=1
minimumQUAL=20

while [ "$1" != "" ]; do
   case $1 in
        -h|-\?|--help)   # Call a "show_help" function to display a synopsis, then exit.
            usage
            exit
            ;;
        --depth)       
            if [ ! -z "$2" ]
            then
               depth="$2"
               shift
            else 
               usage
               exit
            fi
            ;;
        --percentDerived)
            if [ ! -z "$2" ]
            then
               percentDerived="$2"
               shift
            else 
               usage
               exit
            fi
            ;;
        --minimumQUAL)
            if [ ! -z "$2" ]
            then
               minimumQUAL="$2"
            else
               usage
            fi                  
            if [[ "$minimumQUAL" =~ ^[0-9]+$ ]] 
            then
               shift
            else 
               usage
               exit
            fi
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

if [ -f "$1" ] && [ "${1: -7}" == ".vcf.gz" ] 
then
   input="${1}"
else if [ "${1}" != "" ]
     then
        >&2 echo "cannot open ${1} or it is not a valid .vcf.gz file."
  	 usage
   	exit 1
     fi
fi

SN=$(bcftools view -h "${input}" | egrep '^##contig=<ID=.*Y,.*|##contig=<ID=C[MP].*,' | sed -e 's/^##contig=<//' -e 's/>//')

if [[ -z ${SN} ]]
then
   echo "invalid VCF file or VCF link."
   exit 1
fi

Y=$(echo "${SN}" | cut -d',' -f1 | cut -d'=' -f2)
Y_length=$(echo "${SN}" | cut -d',' -f2 | cut -d'=' -f2)

if [[ $Y_length == 57227415 ]]
then
   build=hg38
   REGIONS=${INSTALL_DIR}/reference/Karmin_whitelist_regions-${Y}-${build}.bed
elif [[ $Y_length == 59373566 ]]
then
   build=hg19
   REGIONS=${INSTALL_DIR}/reference/Karmin_whitelist_regions-${Y}-${build}.bed
elif [[ $Y_length == 62460029 && $Y == "chrY" ]]
then
   build=T2T
   REGIONS=${INSTALL_DIR}/reference/NRY-CP086569.2-chrY.bed
else
   echo "unable to determine the reference build of the VCF file."
   exit 1
fi

bcftools query -i 'ID=="." && FILTER=="." && QUAL>='${minimumQUAL} -R ${REGIONS} -f  '%POS\t%REF\t%ALT\t[%AD{0},]\t[%AD{1},]\n' "${input}" | 
awk  -v filter="$filter" -v depth="$depth" -v percentDerived="$percentDerived" -v build="$build" -v Y="$Y" '
BEGIN {
   OFS="\t"; 

   print  "Chromosome", build " start position", build " end position", "Ancestral allele", "Derived allele", "Derived reads", "Total reads", "Percent derived"; 
} 

{
#   print $0
   split($3, genotypes, ",");
   genotype = genotypes[1];

   ref_reads = 0;
   split($4, ref_reads_array, ",");
  
   for (i in ref_reads_array)
   {
       if (ref_reads_array[i] == ".")
       {
          ref_reads_array[i] == 0;
       }

       ref_reads = ref_reads + ref_reads_array[i];
   }

   alt_reads = 0;
   split($5, alt_reads_array, ",");

   for (i in alt_reads_array)
   {
       if (alt_reads_array[i] == ".")
       {
          alt_reads_array[i] == 0;
       }

       alt_reads = alt_reads + alt_reads_array[i];
   }

   ancestral_reads = ref_reads;
   derived_reads = alt_reads;
        
   total_reads = ancestral_reads + derived_reads;
  
   if (total_reads > 0)
   {
      percent_derived = derived_reads / total_reads;
      if (percent_derived >= percentDerived && derived_reads >= depth)
      {
        print Y, $1, $1+1, $2, genotype, derived_reads, total_reads, percent_derived;
      }
   }
}
'
