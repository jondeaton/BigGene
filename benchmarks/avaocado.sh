#!/bin/bash

# In order to subsample the BAM file I used the comment
# "samtools view -bs 42.1 in.bam > subsampled.bam"

# To truncage: 
# samtools view -h NA12878_phased_possorted_bam.bam | head -n 10000000 | samtools view -bS - > little.bam


set -e # Exit if error

# The input sample
SAMPLE="NA12878"
INPUT_DIR="$HOME/Datasets/1000Genomes/NA12878"

# Scratch space
SCRATCH="$INPUT_DIR/scratch"
INTERLEAVED="$SCRATCH/$SAMPLE.ifq"

BAM="$INPUT_DIR/little-subsampled.bam"
ALIGNED="$SCRATCH/$SAMPLE.alignments.adam"
GENOTYPED="$SCRATCH/$SAMPLE.avocado.vcf.bam"
VCF="$SCRATCH/$SAMPLE.avocado.vcf.gz"

# Reference Genome
REF_DIR="$HOME/Datasets/GRCh38/Homo_sapiens/NCBI/GRCh38/Sequence/WholeGenomeFasta"
REF_FA="$REF_DIR/genome.fa"
REF_IDX="$REF_DIR/genome.dict"

# Set SPARK_MEM if it isn't already set since we also use it for this process
SPARK_MEM=${SPARK_MEM:-4g}
export SPARK_MEM

# Set JAVA_OPTS to be able to load native libraries and to set heap size
JAVA_OPTS="$OUR_JAVA_OPTS"
JAVA_OPTS="$JAVA_OPTS -Djava.library.path=$SPARK_LIBRARY_PATH"
JAVA_OPTS="$JAVA_OPTS -Xms$SPARK_MEM -Xmx$SPARK_MEM"


echo "Deleting scratch contents: $SCRATCH"
rm -rf "$SCRATCH"/*

echo "==================== MARKING DUPLICATES, SORTING, TRANSFORMING  ========================="
adam-submit \
	--conf spark.bigstream.xray.overwrite=true \
	--conf spark.bigstream.xray.filename=transformAlignments_xray_log \
	--conf spark.bigstream.xray.dir=. \
	--conf spark.extraListeners=org.apache.spark.bigstream.xray.AXBDXrayListener \
	--conf spark.driver.extraClassPath=spark-bigstream-xray-1.0.3-BIGSTREAM.jar \
	-- transformAlignments \
	"$BAM" "$ALIGNED" \
   -mark_duplicate_reads \
   -sort_reads
    
echo "==================== BIALLELIC GENOTYPER ========================="
avocado-submit \
	--conf spark.bigstream.xray.overwrite=true \
	--conf spark.bigstream.xray.filename=biallelicGenotyper_xray_log \
	--conf spark.bigstream.xray.dir=. \
	--conf spark.extraListeners=org.apache.spark.bigstream.xray.AXBDXrayListener \
	--conf spark.driver.extraClassPath=spark-bigstream-xray-1.0.3-BIGSTREAM.jar \
	-- biallelicGenotyper \
	"$ALIGNED" "$GENOTYPED" \
	-no_chr_prefixes

echo "==================== JOINTER  ========================="
avocado-submit -- jointer \
	"$GENOTYPED" "$VCF" \
	-single

echo "==================== DONE. ========================="
