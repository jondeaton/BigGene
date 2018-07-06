#!/bin/bash

# In order to subsample the BAM file I used the comment
# "samtools view -bs 42.1 in.bam > subsampled.bam"

# To truncage: 
# samtools view -h NA12878_phased_possorted_bam.bam | head -n 10000000 | samtools view -bS - > little.bam

set -e # Exit if error

Green='\033[0;32m'
NC='\033[0m' # No Color

# The input sample
SAMPLE="NA12878"
INPUT_DIR="$HOME/Datasets/1000Genomes/NA12878"

# Database of known SNPs
dbSNP="$HOME/Datasets/dbSNP"
known_snps="$dbSNP/common_all_20180418.vcf.gz"

# Scratch space
SCRATCH="$INPUT_DIR/scratch"
INTERLEAVED="$SCRATCH/$SAMPLE.ifq"
log_dir="logs"

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

# Bigstream acceleration
accelerate=$1
if $accelerate; then
  echo -e  "._:=** Using Bigstream acceleration **=:_."
  bigstream="$HOME/opt/spark-bigstream"
  spark_bigstream="$bigstream/spark-2.1.1-BIGSTREAM-bin-bigstream-spark-yarn-h2.7.2"
  export LD_LIBRARY_PATH="$bigstream/libs"
  export SPARK_HOME="$spark_bigstream"
fi

xray=false
if $xray; then
    echo -e  "Using X-Ray"
    xray_dir="xray"
    XRAY_FLAGS="--conf spark.bigstream.xray.overwrite=true"
    XRAY_FLAGS="$XRAY_FLAGS --conf spark.bigstream.xray.dir=$xray_dir"
    XRAY_FLAGS="$XRAY_FLAGS --conf spark.extraListeners=org.apache.spark.bigstream.xray.AXBDXrayListener"
    XRAY_FLAGS="$XRAY_FLAGS --conf spark.driver.extraClassPath=spark-bigstream-xray-1.0.3-BIGSTREAM.jar"

    xray_extension="xray-log"
    bsql_xray=bsqr."$xray_extension"
fi


echo -e  "${Green}==================== MARKING DUPLICATES, SORTING, TRANSFORMING  =========================${NC}"
rm -rf "$MKDUPS"
adam-submit \
    --conf spark.bigstream.accelerate=$accelerate \
    -- transformAlignments \
    "$BAM" "$MKDUPS" \
    -mark_duplicate_reads \
    -sort_reads 2>&1 | tee "$log_dir/mkdups.log"

echo -e  "${Green}===================== BSQR =====================${NC}"
rm -rf "$BSQR"
adam-submit \
    --conf spark.bigstream.accelerate=$accelerate \
    $XRAY_FLAGS --conf spark.bigstream.xray.filename=bsqr."$xray_extension" \
    -- transformAlignments \
    "$MKDUPS" "$BSQR" \
    -recalibrate_base_qualities 2>&1 | tee "$log_dir/bsqr.log"
    # -known_snps "$known_snps"

echo -e  "${Green}===================== REALIGNMENT ========================${NC}"
rm -rf "$REALIGNED"
adam-submit \
    --conf spark.bigstream.accelerate=$accelerate \
    $XRAY_FLAGS --conf spark.bigstream.xray.filename=realign."$xray_extension" \
    -- transformAlignments \
    "$BSQR" "$REALIGNED" \
    -realign_indels \
    -aligned_read_predicate \
    -max_consensus_number 32 \
    -max_reads_per_target 256 \
    -max_target_size 2048 \
    -limit_projection \
    -log_odds_threshold 0.5 2>&1 | tee "$log_dir/realign.log"
    # f-reference "$REF_FA"
   
# REALIGNED="$MKDUPS" # skip BSQR and realignment

echo -e  "${Green}==================== BIALLELIC GENOTYPER =========================${NC}"
rm -rf "$GENOTYPED"
avocado-submit \
    --conf spark.bigstream.accelerate=$accelerate \
    $XRAY_FLAGS --conf spark.bigstream.xray.filename=genotyper."$xray_extension" \
	-- biallelicGenotyper "$REALIGNED" "$GENOTYPED" -no_chr_prefixes 2>&1 | tee i"$log_dir/genotyper.log"

echo -e  "${Green}==================== JOINTER  =========================${NC}"
rm -rf "$VCF"
avocado-submit \
    --conf spark.bigstream.accelerate=$accelerate \
    $XRAY_FLAGS --conf spark.bigstream.xray.filename=genotyper."$xray_extension" \
    -- jointer \
    "$GENOTYPED" "$VCF" \
    -single 2>&1 | tee "$log_dir/joiner.log"

echo -e  "${Green}==================== DONE. =========================${NC}"

