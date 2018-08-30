#!/usr/bin/env bash

ORIGINAL="$HOME/Datasets/1000Genomes/NA12878/downsampled/little-subsampled.bam"
CORRECT="correct_mkdups.bam"
#CORRECT="simpler_mkdups.bam"
CHECK="mkdups.bam"

#ORIGINAL="$HOME/Datasets/1000Genomes/NA12878/downsampled/10000000-NA12878_phased_possorted_bam.bam"
#CORRECT="big_correct_mkdups.bam"
#CHECK="big_sql_mkdups.bam"

python correctness.py --debug --input "$ORIGINAL" --correct "$CORRECT" --check "$CHECK"
