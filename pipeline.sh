#!/usr/bin/env bash
set -e

# pipeline.sh: run the whole pipeline from scratch

cd haps

# Grab the reference
wget "http://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz"
gzip -d "hg38.fa.gz"

# Download the input haplotypes
for i in `cat haps.urls`; do wget $i; done
# Create a VCF from them
./make-vcf.sh

# Make and index a graph with construct
./do-by-chroms.sh
# And with vg add
./do-by-add.sh

cd ../genotyping

# Make the control graphs
./make-controls.sh

# Run simulation, calling, and genotyping on the construct-based graphs
./sim-test.sh HG005733 ../haps/hgsvc_chr21.threads 
./sim-test.sh HG00514 ../haps/hgsvc_chr21.threads
./sim-test.sh NA19240 ../haps/hgsvc_chr21.threads

# Run simulation, calling, and genotyping on the add-based graphs
./sim-test.sh HG005733 ../haps/hgsvc_add_chr21  
./sim-test.sh HG00514 ../haps/hgsvc_add_chr21 
./sim-test.sh NA19240 ../haps/hgsvc_add_chr21

# Print results
for i in  `ls simtest-hgsvc_*/hgsvc-call_vcfeval_output_summary.txt`; do echo $i; cat $i; done


