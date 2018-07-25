#!/usr/bin/env bash

ORIGINAL="$HOME/Datasets/1000genomes/NA12878/little-subsampled.bam"
CORRECT="correct_mkdups.bam"
CHECK="sql_mkdups.bam"

python correctness.py --debug --input "$ORIGINAL" --correct "$CORRECT" --check "$CHECK"
