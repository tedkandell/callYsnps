#/bin/bash

if [ $# == 0 ] || ( [ ${1: -4} != ".bam" ] && [ ${1: -5} != ".cram" ] )
then
    echo "usage: callYSNPs.sh <Build 37 or Build 38 or T2T-CHM13v2.0 BAM file>"
    exit 1;
fi

INSTALL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# determine Y chromosome sequence name

bam="$1"
#if [ ${1: -4} != ".bam" ]
if [[ ${bam} == *.bam ]]
then
   base_filename=${bam%.bam}
   filetype="bam"
   indextype="bai"
#elif [ ${1: -5} != ".cram" ]
elif [[ ${bam} == *.cram ]]
then
   base_filename=${bam%.cram}
   filetype="cram"
   indextype="crai"
fi

base_filename="${bam%.*}"


base_filename=${base_filename##*/}
echo "determining Y chromosome name and build for ${base_filename}.$filetype ..."
#Y=$(samtools view -H "${bam}" | grep "^@SQ.*SN:.*Y" | cut -f2 | sed 's/SN://')

#SN=$(samtools view -H "${bam}" | grep "^@SQ.*SN:.*Y")
SN=$(samtools view -H "${bam}" | grep '^@SQ.*SN:.*Y	\|^@SQ.*SN:C')

echo $SN
if [[ -z ${SN} ]]
then
   echo "invalid BAM or CRAM file or BAM or CRAM link."
   exit 1
fi

Y=$(echo "${SN}" | cut -f2 | sed 's/SN://')
Y_length=$(echo "${SN}" | cut -f3 | sed 's/LN://')

if [[ $Y_length == 57227415 ]]
then
   build=hg38
elif [[ $Y_length == 59373566 ]]
then
   build=hg19
elif [[ $Y_length == 62460029 ]]
then
   build=T2T
else
   echo "unable to determine the reference build of the BAM or CRAM file."
   exit 1 
fi

hg19_reference=${INSTALL_DIR}/reference/human_g1k_v37-${Y}.fasta.gz
hg38_reference=${INSTALL_DIR}/reference/hg38-${Y}.fa.gz 
T2T_reference=${INSTALL_DIR}/reference/CP086569.2-chrY/CP086569.2-chrY.fa.gz
Y_annotation=${INSTALL_DIR}/tree/SNPs-${Y}-annotation-${build}.bed.gz
annotation_header=${INSTALL_DIR}/tree/annotation.header

if [[ "$build" == "hg38" ]]
then
    reference="${hg38_reference}"
    ploidy="GRCh38"
elif [[ "$build" == "hg19" ]]
then
    reference="${hg19_reference}"
    ploidy="GRCh37"
elif [[ "$build" == "T2T" ]]
then
    reference="${T2T_reference}":
    ploidy="1"
#elif [[ "$build" == "PR1" ]]
#then
#    reference="${CM034974_reference}"
#    ploidy="1"
fi

echo "${base_filename}.$filetype Y sequence name: ${Y} Build: ${build}"

if [[ ${bam} != http:* ]] && [[ ${bam} != ftp:* ]]  && [[ ! -f "${bam}.$indextype" ]] 
then
   echo "BAM index not found, indexing ${bam} ..."
   samtools index "${base_filename}.$filetype"
   if [ $? -ne 0 ]
   then
      echo "indexing of ${base_filename}.$filetype failed."
      exit 1
   fi      
   echo "done."
fi

echo "genome reference to be used:  ${reference}"

# samtools mpileup -B is needed to disable Base Alignment Quality realignment computations, 
# and to include ALL bases, even those at the end of reads

# bcftools call -A is needed to preserve the ALT alleles in all cases.

echo "calling Y SNPs for ${base_filename}.$filetype"
echo "and annotating ${base_filename%-$Y}-${Y}-annotated.vcf.gz ..."
bcftools mpileup -IB -r ${Y} --fasta-ref ${reference} -a AD "${bam}" | bcftools call -mA --ploidy ${ploidy} | bcftools +missing2ref | bcftools annotate -c CHROM,FROM,TO,ID,AA,DA,HG,YF -a ${Y_annotation} -h ${annotation_header} | bgzip -c  > ${base_filename%-$Y}-${Y}-annotated.vcf.gz && tabix -fp vcf ${base_filename%-$Y}-${Y}-annotated.vcf.gz

if [[ ${bam} == http:* ]] || [[ ${bam} == ftp:* ]]
then
   if [[ ${bam: -4} == ".bam" ]]
   then
      index_bam=$(ls ${base_filename}*.bai)
      if [[ -f ${index_bam} ]]
      then
         echo "deleting downloaded BAM index file ${index_bam}"
         rm ${index_bam}
      fi
   fi

   if [[ ${bam: -5} == ".cram" ]]
   then
      index_cram=$(ls ${base_filename}*.crai)
      if [[ -f ${index_cram} ]]
      then
         echo "deleting downloaded CRAM index file ${index_cram}"
         rm ${index_cram}
      fi
   fi
fi

echo "done."
