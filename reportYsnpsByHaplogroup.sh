#/bin/bash

function usage()
{
    >&2 echo "usage: reportYsnpsByHaplogroup.sh [-h|--help] [--filter <haplogroup name>] [--derived] [.vcf.gz file | stdin (default)]"
}

INSTALL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

PathLookupTable=${INSTALL_DIR}/tree/haplogroupPathLookupTable.tsv

sort="-k9 -k2"

while [ "$1" != "" ]; do
   case $1 in
        -h|-\?|--help)   # Call a "show_help" function to display a synopsis, then exit.
            usage
            exit
            ;;
        --filter)     
            if [ ! -z "$2" ]
            then
               filter="$2"
               shift
            else 
               usage
            fi
            ;;
        --derived)
           derived="TRUE"
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

if [ ! -f ${PathLookupTable} ]
then

   >&2 echo "cannot open haplogroup path lookup table: ${PathLookupTable}"
   usage
   exit 1
fi

SN=$(bcftools view -h "${input}" | egrep '^##contig=<ID=.*Y,.*|##contig=<ID=C[MP].*,' | sed -e 's/^##contig=<//' -e 's/>//')

if [[ -z ${SN} ]]
then
   echo "invalid VCF file or VCF link."
   exit 1
fi

Y=$(echo "${SN}" | cut -d',' -f1 | cut -d'=' -f2)
Y_length=$(echo "${SN}" | cut -d',' -f2 | cut -d'=' -f2)

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
elif [[ $Y_length == 59373566 ]]
then
   build=hg19
elif [[ $Y_length == 62460029 ]]
then
   build=T2T
elif [[ $Y_length == 62480187 ]]
then
   build=PR1
else
   echo "unable to determine the reference build of the BAM file."
   exit 1
fi

temp_file=mktemp
trap 'rm -f "$temp_file"' EXIT

bcftools query -i 'ID !="."' -f '%ID\t%POS\t%FIRST_ALT\t%AA\t%DA\t[%AD{0},]\t[%AD{1},]\t%HG\t%YF\t%REF\t%TYPE\n' "${input}" | 
sort ${sort} -V | 
awk -v filter="$filter" -v derived="$derived" -v build="$build" -v Y="$Y" -v PathLookupTable=$PathLookupTable -v temp_file="$temp_file" '
BEGIN {
   FS=OFS="\t"; 

   while (( getline line < PathLookupTable) > 0 ) 
   {
      split(line, fields)
      pathLookup[fields[1]] = fields[2]
   }

   close(PathLookupTable)
} 

{
   is_derived = $5 "+";
   sign = "-"; 

   genotype = $3;

   if ($3 == ".")
   {
      genotype = $10;
   }

   if (genotype ~ is_derived)
   {
      sign = "+";
   }

   ref_reads = 0;
   split($6, ref_reads_array, ",");
  
   for (i in ref_reads_array)
   {
       if (ref_reads_array[i] == ".")
       {
          ref_reads_array[i] == 0;
       }

       ref_reads = ref_reads + ref_reads_array[i];
   }

   alt_reads = 0;
   split($7, alt_reads_array, ",");

   for (i in alt_reads_array)
   {
       if (alt_reads_array[i] == ".")
       {
          alt_reads_array[i] == 0;
       }

       alt_reads = alt_reads + alt_reads_array[i];
   }

   if ($10 == $5) {
      ancestral_reads = alt_reads;
      derived_reads = ref_reads;
   } 
   else {
      ancestral_reads = ref_reads;
      derived_reads = alt_reads;
   }      

   if (genotype != $5 && genotype != $4)
   {
     ancestral_reads = derived_reads;
     derived_reads = 0;
   } 

   total_reads = ancestral_reads + derived_reads;
  
   if (total_reads > 0)
   {
      percent_derived = derived_reads / total_reads;
      
      if (percent_derived >= 0.5 && total_reads > 2)
      {  
         sign = "+";
      }
      else if (percent_derived == 0.5 && total_reads == 2)
      {
         sign = "?";
      }
      else if (percent_derived > 0 && percent_derived < 0.5)
      { 
         sign = "?";
      }
   }
   else {
      genotype = "DEL";
       
      if ($5 == "DEL")
      {
         sign = "+"; 
         percent_derived = 1;      
      }
      else {
         sign = "-";
         percent_derived = 0;      
      }
   }

   split($9, haplogroups_array, "&");
  
   for (i in haplogroups_array)
   {
      if (derived != "" && sign != "+")
      {
         next;
      } 

      path = pathLookup[haplogroups_array[i]];
 
      if (path == "")
      {
         path = "Ξ";
      }
      
      filter_regex = ">" filter "$|" ">" filter ">|" "^" filter ">";
      
      if (filter == "" || (filter != "" && path ~ filter_regex))
      {
         print sign, Y, $2, $2+1, genotype, $4, $5, ancestral_reads, derived_reads, percent_derived, $1, $8, haplogroups_array[i], path >> temp_file;
      }
   }
}

END {

   print "#State", "Chromosome", build " start position", build " end position", "Genotype", "Ancestral allele", "Derived allele", "Ancestral reads", "Derived reads", "Derived reads/Total reads", "SNP names", "ISOGG Haplogroup", "YFull haplogroup", "YFull haplogroup path"; 
}
'
sort -k14,14 -t$'\t' $temp_file

