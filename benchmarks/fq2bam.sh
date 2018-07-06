#!/bin/sh
# This script should work, but it doens't because, you know... bioinformatics

set -e # Exit if error 

# The input sample
DIR="$HOME/Datasets/1000Genomes/sample"
R1="$DIR/U0a_CGATGT_L001_R1_001.fastq.gz"
R2="$DIR/U0a_CGATGT_L001_R2_001.fastq.gz"

# Reference Genome
REF_DIR="$HOME/Datasets/GRCh38/Homo_sapiens/NCBI/GRCh38/Sequence/WholeGenomeFasta"
REF_FA="$REF_DIR/genome.fa"
REF_IDX="$REF_DIR/genome.dict"

# Output files
SCRATCH="$DIR/analysis"
IFQ="$SCRATCH/combined.ifq"
BAM="$SCRATCH/U0a.bam"

echo "==================== INTERLEAVING FASTQ FILES  ========================="
cannoli-submit -- interleaveFastq $R1 $R2 $IFQ

echo "==================== ALIGNING TO REFERENCE WITH BWA ========================="
cannoli-submit -- bwa \
  "$DIR/comb.ifq" $BAM "sampleID" \
    -index $REF_FA \
    -stringency "LENIENT" \
    -sequence_dictionary $REF_IDX 

