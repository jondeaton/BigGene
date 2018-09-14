#!/usr/bin/env bash

ORIGINAL="/usr/remote/share/workspace/jon/little-subsampled.bam"
CORRECT="correct_mkdups.bam"
OUTPUT_CHECK="mkdups.bam"

# bigger comparison
#ORIGINAL="/usr/remote/share/workspace/jon/NA12878-downsampled/10000000-NA12878_phased_possorted_bam.bam"
#CORRECT="big_correct_mkdups.bam"
#OUTPUT_CHECK="big_sql_mkdups.bam"

python correctness.py --debug --input "$ORIGINAL" --correct "$CORRECT" --check "$OUTPUT_CHECK"
