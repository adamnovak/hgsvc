#!/bin/bash
set -e

# Make some indexes for bwa and primary graph controls

#wget http://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz
#gzip -d hg38.fa.gz
HG38=../haps/hg38.fa 

#chroms=$(cat $ref.fai | cut -f 1)
#chroms=$(for i in $(seq 1 22; echo X; echo Y); do echo chr${i}; done)
chroms=chr21
#HG38=../haps/hg38_chr21.fa 

if [[ ! -e ./controls/primary.gcsa.lcp ]] ; then
    #Make a primary control graph and its indexes
    rm -rf jsc ; toil-vg construct ./jsc ./controls --fasta ${HG38} --region ${chroms} --container None --realTimeLogging  --xg_index --gcsa_index --out_name hg38  --primary  --workDir . --gcsa_index_cores 20
fi

if [[ ! -e ./controls/hgsvc.norm_HG00514.gcsa.lcp ]] ; then
    #Make a positive control graph and its indexes
    rm -rf jsc ; toil-vg construct ./jsc ./controls --fasta ${HG38} --vcf ../haps/HGSVC.HG00514.vcf.gz --pos_control HG00514 --region ${chroms} --container None --realTimeLogging  --xg_index --gcsa_index --out_name hgsvc.norm --flat_alts --normalize  --workDir . --gcsa_index_cores 20 --whole_genome_config --gbwt_index --gbwt_prune
fi


if [[ ! -e ./controls/hg38.fa.bwt ]] ; then
    #Make a bwa index
    bwa index ${HG38} -p ./controls/hg38.fa
fi

