#!/bin/sh

# EMR cluster with:
# 1x 16 vCPUs 30G RAM master node (m3.2xlarge)
# 8x 16 vCPUs 61G RAM worker nodes (r3.2xlarge)
DRIVER_MEMORY="22G"
DRIVER_CORES="14"
EXECUTOR_MEMORY="50G"
EXECUTOR_CORES="14"

HDFS_DIR="/data"
HDFS_PATH="hdfs://spark-master:8020$HDFS_DIR"

BAM_FILENAME="20000000-NA12878_phased_possorted_bam.bam"
S3_FILE="s3://bigstream-genomics3/NA12878/$BAM_FILENAME"

echo "creating $HDFS_DIR directory on hdfs..."
hadoop fs -mkdir -p "$HDFS_DIR"

s3-dist-cp --src "$S3_FILE" --dst "$HDFS_PATH/$BAM_FILENAME"

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
    "$BAM" "$MKDUPS" \
    -mark_duplicate_reads \
    -single 2>&1 \
    -sort_reads | tee mkdups.log
