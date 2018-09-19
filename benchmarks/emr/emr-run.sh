#!/bin/sh

# EMR cluster with:
# 1x 16 vCPUs 30G RAM master node (m3.2xlarge)
# 8x 16 vCPUs 61G RAM worker nodes (r3.2xlarge)
DRIVER_MEMORY="4G"
DRIVER_CORES="4"
EXECUTOR_MEMORY="5G"
EXECUTOR_CORES="4"

BAM_FILENAME="20000000-NA12878_phased_possorted_bam.bam"
S3_FILE="s3://bigstream-genomics3/NA12878/$BAM_FILENAME"
MKDUPS="s3://bigstream-genomics3/mkdups.adam"

adam_submit="adam/bin/adam-submit"

time $adam_submit \
    --name "Mark Duplicates" \
    --master yarn \
    --deploy-mode cluster \
    --driver-memory $DRIVER_MEMORY \
    --executor-memory $EXECUTOR_MEMORY \
    --conf spark.driver.cores=$DRIVER_CORES \
    --conf spark.executor.cores=$EXECUTOR_CORES \
    --conf spark.yarn.executor.memoryOverhead=2048 \
    -- transformAlignments \
    "$S3_FILE" "$MKDUPS" \
    -mark_duplicate_reads \
    -single 2>&1 \
    -sort_reads | tee mkdups.log
