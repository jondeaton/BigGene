#!/usr/bin/env bash

CORRECT="correct_mkdups.bam"
OUTPUT_CHECK="mkdups.bam"

python correctness.py --debug --correct "$CORRECT" --check "$OUTPUT_CHECK"
