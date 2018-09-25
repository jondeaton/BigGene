#!/bin/bash

# In order to subsample the BAM file I used the comment
# "samtools view -bs 42.1 in.bam > subsampled.bam"

# To truncage: 
# samtools view -h NA12878_phased_possorted_bam.bam | head -n 10000000 | samtools view -bS - > little.bam

# set -e # Exit if error

Green='\033[0;32m'
NC='\033[0m' # No Color

# The input sample
in=$1
SAMPLE=`basename $in .bam`

# Database of known SNPs
dbSNP="$HOME/Datasets/dbSNP"
known_snps="$dbSNP/common_all_20180418.vcf.gz"

# Scratch space
SCRATCH=$2
INTERLEAVED="$SCRATCH/$SAMPLE.ifq"
log_dir="logs"

# Intermediate files (and output)
BAM="$in"
MKDUPS="$SCRATCH/$SAMPLE.mkdups.adam"
BSQR="$SCRATCH/$SAMPLE.bsqr.adam"
REALIGNED="$SCRATCH/$SAMPLE.algn.adam"
GENOTYPED="$SCRATCH/$SAMPLE.avocado.vcf.adam"
VCF="$SCRATCH/$SAMPLE.avocado.vcf.gz" # final output file

# Reference Genome
REF_DIR="$HOME/Datasets/GRCh38/Homo_sapiens/NCBI/GRCh38/Sequence/WholeGenomeFasta"
REF_FA="$REF_DIR/genome.fa"
REF_IDX="$REF_DIR/genome.dict"

#ADAM/Avocado setup
adam_submit="../bdgenomics/adam/bin/adam-submit"
avocado_submit="../bdgenomics/avocado/bin/avocado-submit"

# Set SPARK_MEM if it isn't already set since we also use it for this process
SPARK_MEM=${SPARK_MEM:-6g}
export SPARK_MEM

# Set JAVA_OPTS to be able to load native libraries and to set heap size
JAVA_OPTS="$JAVA_OPTS -Djava.library.path=$SPARK_LIBRARY_PATH"
JAVA_OPTS="$JAVA_OPTS -Xms$SPARK_MEM -Xmx$SPARK_MEM"

echo -e  "${Green}==================== MARKING DUPLICATES, SORTING, TRANSFORMING  =========================${NC}"
rm -rf "$MKDUPS"
start=`date +%s`
time $adam_submit \
    --conf spark.bigstream.accelerate=$accelerate \
    -- transformAlignments \
    "$BAM" "$MKDUPS" \
    -mark_duplicate_reads \
    -sort_reads 2>&1 | tee "$log_dir/mkdups.log"
end=`date +%s`
mkdups_time=$((end-start))

echo -e  "${Green}===================== BSQR =====================${NC}"
rm -rf "$BSQR"
start=`date +%s`
time $adam_submit \
    --conf spark.bigstream.accelerate=$accelerate \
    $XRAY_FLAGS --conf spark.bigstream.xray.filename=bsqr."$xray_extension" \
    -- transformAlignments \
    "$MKDUPS" "$BSQR" \
    -recalibrate_base_qualities 2>&1 | tee "$log_dir/bsqr.log"
    # -known_snps "$known_snps"
end=`date +%s`
bsqr_time=$((end-start))

echo -e  "${Green}===================== REALIGNMENT ========================${NC}"
rm -rf "$REALIGNED"
start=`date +%s`
time $adam_submit \
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
end=`date +%s`
realign_time=$((end-start))

echo -e  "${Green}==================== BIALLELIC GENOTYPER =========================${NC}"
rm -rf "$GENOTYPED"
start=`date +%s`
time $avocado_submit \
    --conf spark.bigstream.accelerate=$accelerate \
    $XRAY_FLAGS --conf spark.bigstream.xray.filename=genotyper."$xray_extension" \
	-- biallelicGenotyper "$REALIGNED" "$GENOTYPED" -no_chr_prefixes 2>&1 | tee i"$log_dir/genotyper.log"
end=`date +%s`
genotyper_time=$((end-start))

echo -e  "${Green}==================== JOINTER  =========================${NC}"
rm -rf "$VCF"
start=`date +%s`
time $avocado_submit \
    --conf spark.bigstream.accelerate=$accelerate \
    $XRAY_FLAGS --conf spark.bigstream.xray.filename=genotyper."$xray_extension" \
    -- jointer \
    "$GENOTYPED" "$VCF" \
    -single 2>&1 | tee "$log_dir/joiner.log"
end=`date +%s`
jointer_time=$((end-start))

echo -e  "${Green}==================== DONE. =========================${NC}"

echo "Mark Duplicates: $mkdups_time s"
echo "BSQR: $bsqr_time s"
echo "Realignment: $realign_time s"
echo "Biallelic Genotyper: $genotyper_time s"
echo "Jointer: $jointer_time s"
