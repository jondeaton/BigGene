#!/bin/bash

# In order to subsample the BAM file I used the comment
# "samtools view -bs 42.1 in.bam > subsampled.bam"

# To truncage: 
# samtools view -h NA12878_phased_possorted_bam.bam | head -n 10000000 | samtools view -bS - > little.bam

set -e # Exit if error

# The input sample
SAMPLE="NA12878"
INPUT_DIR="$HOME/Datasets/1000Genomes/NA12878"

# Database of known SNPs
dbSNP="$HOME/Datasets/dbSNP"
known_snps="$dbSNP/common_all_20180418.vcf.gz"

# Scratch space
SCRATCH="$INPUT_DIR/scratch"
INTERLEAVED="$SCRATCH/$SAMPLE.ifq"

# Intermediate files (and output)
BAM="$INPUT_DIR/little-subsampled.bam"
MKDUPS="$SCRATCH/$SAMPLE.mkdups.adam"
BSQR="$SCRATCH/$SAMPLE.bsqr.adam"
REALIGNED="$SCRATCH/$SAMPLE.algn.adam"
GENOTYPED="$SCRATCH/$SAMPLE.avocado.vcf.adam"
VCF="$SCRATCH/$SAMPLE.avocado.vcf.gz" # final output file

# Reference Genome
REF_DIR="$HOME/Datasets/GRCh38/Homo_sapiens/NCBI/GRCh38/Sequence/WholeGenomeFasta"
REF_FA="$REF_DIR/genome.fa"
REF_IDX="$REF_DIR/genome.dict"

# Set SPARK_MEM if it isn't already set since we also use it for this process
SPARK_MEM=${SPARK_MEM:-6g}
export SPARK_MEM

# Set JAVA_OPTS to be able to load native libraries and to set heap size
JAVA_OPTS="$OUR_JAVA_OPTS"
JAVA_OPTS="$JAVA_OPTS -Djava.library.path=$SPARK_LIBRARY_PATH"
JAVA_OPTS="$JAVA_OPTS -Xms$SPARK_MEM -Xmx$SPARK_MEM"

echo "==================== MARKING DUPLICATES, SORTING, TRANSFORMING  ========================="
rm -r "$MKDUPS"
adam-submit \
    --conf spark.logLineage=true \
    --conf spark.bigstream.xray.overwrite=true \
    --conf spark.bigstream.xray.filename="mkdups-xray-log" \
    --conf spark.bigstream.xray.dir="xray" \
    --conf spark.extraListeners=org.apache.spark.bigstream.xray.AXBDXrayListener \
    --conf spark.driver.extraClassPath=spark-bigstream-xray-1.0.3-BIGSTREAM.jar \
    -- transformAlignments \
    "$BAM" "$MKDUPS" \
    -mark_duplicate_reads \
    -sort_reads

echo "===================== BSQR ====================="
rm -r "$BSQR"
adam-submit \
    --conf spark.logLineage=true \
    --conf spark.bigstream.xray.overwrite=true \
    --conf spark.bigstream.xray.filename="bsqr-xray-log" \
    --conf spark.bigstream.xray.dir="xray" \
    --conf spark.extraListeners=org.apache.spark.bigstream.xray.AXBDXrayListener \
    --conf spark.driver.extraClassPath=spark-bigstream-xray-2.0.3-BIGSTREAM.jar \
    -- transformAlignments \
    "$MKDUPS" "$BSQR" \
    -recalibrate_base_qualities
    # -known_snps "$known_snps"

echo " ===================== REALIGNMENT ========================"
rm -r "$REALIGNED"
adam-submit \
    --conf spark.logLineage=true \
    --conf spark.bigstream.xray.overwrite=true \
    --conf spark.bigstream.xray.filename="realign-xray-log" \
    --conf spark.bigstream.xray.dir="xray" \
    --conf spark.extraListeners=org.apache.spark.bigstream.xray.AXBDXrayListener \
    --conf spark.driver.extraClassPath=spark-bigstream-xray-1.0.3-BIGSTREAM.jar \
    -- transformAlignments \
    "$BSQR" "$REALIGNED" \
    -realign_indels \
    -aligned_read_predicate \
    -max_consensus_number 32 \
    -max_reads_per_target 256 \
    -max_target_size 2048 \
    -limit_projection \
    -log_odds_threshold 0.5 
    # f-reference "$REF_FA"
   
# REALIGNED="$MKDUPS" # skip BSQR and realignment

echo "==================== BIALLELIC GENOTYPER ========================="
rm -r "$GENOTYPED"
avocado-submit \
	 --conf spark.logLineage=true \
   --conf spark.bigstream.xray.overwrite=true \
   --conf spark.bigstream.xray.filename="genotyper-xray-log" \
   --conf spark.bigstream.xray.dir="xray" \
   --conf spark.extraListeners=org.apache.spark.bigstream.xray.AXBDXrayListener \
	 --conf spark.driver.extraClassPath=spark-bigstream-xray-1.0.3-BIGSTREAM.jar \
	 -- biallelicGenotyper "$REALIGNED" "$GENOTYPED" -no_chr_prefixes

echo "==================== JOINTER  ========================="
rm -r "$VCF"
avocado-submit \
    --conf spark.logLinear=true \
    --conf spark.bigstream.xray.overwrite=true \
    --conf spark.bigstream.xray.filename="joiner-xray-log" \
    --conf spark.bigstream.xray.dir="xray" \
    --conf spark.extraListeners=org.apache.spark.bigstream.xray.AXBDXrayListener \
    --conf spark.driver.extraClassPath=spark-bigstream-xray-1.0.3-BIGSTREAM.jar \
    -- jointer \
    "$GENOTYPED" "$VCF" \
    -single

echo "==================== DONE. ========================="
