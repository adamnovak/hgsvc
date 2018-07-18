# Simulate reads from a sample in the hgsvc graph, map them back, then 
# run vg call to make a vcf. requires that graphs have been made by running
# ./make-vcf.sh and ./do-by-chrom.sh hgsvc_v1 in ../haps/

#!/bin/bash

usage() {
    # Print usage to stderr
    exec 1>&2
    printf "Usage: $0 <Sample> \n"
    exit 1
}

while getopts "" o; do
    case "${o}" in
        *)
            usage
            ;;
    esac
done

shift $((OPTIND-1))

if [[ "$#" -lt "1" ]]; then
    # Too few arguments
    usage
fi

# Needs to have been made in ../haps so: HG007733 or HG00514 or NA19240
SAMPLE="${1}"
shift

#wget http://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz
#gzip -d hg38.fa.gz
HG38=../haps/hg38.fa 

CHROM=chr21
GAM_PREFIX=${SAMPLE}_sim_5M
NUMREADS=5000000
JS=./js_${SAMPLE}_${NUMREADS}

# Make a sample VCF
gzip -dc ../haps/${SAMPLE}.haps.vcf.gz | vcfkeepinfo - NA | vcffixup - | bgziptabix ./${SAMPLE}.vcf.gz 

# Make a graph for each haplotype thread of SAMPLE to simulate from
rm -rf ${JS} haplo.log; toil-vg construct ${JS} ./simtest-${SAMPLE} --realTimeLogging --vcf ./${SAMPLE}.vcf.gz --fasta ${HG38} --haplo_sample ${SAMPLE} --xg_index --regions ${CHROM} --out_name hgsvc_baseline --logFile haplo.log

# Simulate some reads for this sample using thread graphs made above
rm -rf ${JS} sim.log; toil-vg sim ${JS} ./simtest-${SAMPLE}/hgsvc_baseline_${SAMPLE}_haplo_thread_0.xg ./simtest-${SAMPLE}/hgsvc_baseline_${SAMPLE}_haplo_thread_1.xg ${NUMREADS} ./simtest-${SAMPLE} --realTimeLogging --fastq ftp://ftp-trace.ncbi.nlm.nih.gov/giab/ftp/data/NA12878/NIST_NA12878_HG001_HiSeq_300x/131219_D00360_005_BH814YADXX/Project_RM8398/Sample_U5a/U5a_AGTCAA_L002_R1_007.fastq.gz --gam  --out_name ${GAM_PREFIX} --fastq_out --sim_chunks 20 --logFile sim.log --seed 23

# Make a version of the reads for bwa
bgzip -dc ./simtest-${SAMPLE}/${GAM_PREFIX}.fq.gz - | sed 's/fragment_\([0-9]*\)_[0-9]/fragment_\1/g' | bgzip > ./simtest-${SAMPLE}/${GAM_PREFIX}_bwa.fq.gz &

# Remap simulated reads to the full graph (takes about 3.5 hours on 32 cores)
echo "Mapping simulated reads back to hgsvc graph"
vg map -d ../haps/hgsvc_v1.threads -f ./simtest-${SAMPLE}/${GAM_PREFIX}.fq.gz -i  -t 20 > ./simtest-${SAMPLE}/${GAM_PREFIX}_remapped.gam

# Remap simulated reads to the control graph
vg map -d ./controls/primary -f ./simtest-${SAMPLE}/${GAM_PREFIX}.fq.gz -i  -t 20 > ./simtest-${SAMPLE}/${GAM_PREFIX}_remapped_primary.gam

# bwa mapping
bwa mem ./hg38.fa ./simtest-${SAMPLE}/${GAM_PREFIX}_bwa.fq.gz -p -t 32 | samtools view -bS - > ./simtest-${SAMPLE}/${GAM_PREFIX}_bwa_remapped.bam

# run the calling and vcf evaluation
rm -rf ${JS} calleval.log; toil-vg calleval ${JS} ./simtest-${SAMPLE}/ --whole_genome_config --realTimeLogging --bams ./simtest-${SAMPLE}/${GAM_PREFIX}_bwa_remapped.bam --bam_names bwa --chroms ${CHROM} --gams ./simtest-${SAMPLE}/${GAM_PREFIX}_remapped.gam ./simtest-${SAMPLE}/${GAM_PREFIX}_remapped_primary.gam --gam_names snp1kg primary --xg_paths ../haps/hgsvc_v1.threads.xg ./controls/primary.xg --vcfeval_fasta ${HG38} --vcfeval_baseline ../haps/HGSVC.haps.vcf.gz --vcfeval_opts " --squash-ploidy" --logFile calleval.log --call --freebayes  --sample_name ${SAMPLE} --workDir .