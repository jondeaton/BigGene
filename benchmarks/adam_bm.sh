#!/bin/bash

# adam_bm.sh s3://source sample s3://dest
SRC_DIR=$1
SAMPLE=$2
DEST_DIR=$3
HDFS_DIR="/data"
HDFS_PATH="hdfs://spark-master:8020$HDFS_DIR"
REFERENCE=""

# EMR cluster with:
# 1x 16 vCPUs 30G RAM master node (m3.2xlarge)
# 8x 16 vCPUs 61G RAM worker nodes (r3.2xlarge)
DRIVER_MEMORY="22G"
DRIVER_CORES="14"
EXECUTOR_MEMORY="50G"
EXECUTOR_CORES="14"

echo "creating $HDFS_DIR directory on hdfs..."
hadoop fs -mkdir -p "$HDFS_DIR"

echo "downloading $SRC_DIR/${SAMPLE}_1.fq.gz to $HDFS_PATH/${SAMPLE}_1.fq.gz with conductor..."
spark-submit \
    conductor-0.5-SNAPSHOT/conductor-0.5-SNAPSHOT-distribution.jar \
    $SRC_DIR/${SAMPLE}_1.fq.gz \
    $HDFS_PATH/${SAMPLE}_1.fq.gz \
    --concat

echo "downloading $SRC_DIR/${SAMPLE}_2.fq.gz to $HDFS_PATH/${SAMPLE}_2.fq.gz with conductor..."
spark-submit \
    conductor-0.5-SNAPSHOT/conductor-0.5-SNAPSHOT-distribution.jar \
    $SRC_DIR/${SAMPLE}_2.fq.gz \
    $HDFS_PATH/${SAMPLE}_2.fq.gz \
    --concat

echo "interleaving ${SAMPLE}_1.fq.gz and ${SAMPLE}_2.fq.gz to $HDFS_PATH/$SAMPLE.ifq..."
cannoli-submit \
    --master yarn \
    --deploy-mode cluster \
    --driver-memory $DRIVER_MEMORY \
    --executor-memory $EXECUTOR_MEMORY \
    --conf spark.driver.cores=$DRIVER_CORES \
    --conf spark.executor.cores=$EXECUTOR_CORES \
    --conf spark.yarn.executor.memoryOverhead=2048 \
    -- \
    interleaveFastq \
    -single \
    $HDFS_PATH/${SAMPLE}_1.fq.gz \
    $HDFS_PATH/${SAMPLE}_2.fq.gz \
    $HDFS_PATH/$SAMPLE.ifq
    
echo "aligning $SAMPLE to reference $REFERENCE with bwa via cannoli..."
cannoli-submit \
    --master yarn \
    --deploy-mode cluster \
    --driver-memory $DRIVER_MEMORY \
    --executor-memory $EXECUTOR_MEMORY \
    --conf spark.driver.cores=$DRIVER_CORES \
    --conf spark.executor.cores=$EXECUTOR_CORES \
    --conf spark.yarn.executor.memoryOverhead=2048 \
    -- \
    bwa \
    -index $REFERENCE \
    -single \
    -stringency LENIENT \
    $HDFS_PATH/$SAMPLE.ifq
    $HDFS_PATH/$SAMPLE.bam
    $SAMPLE

echo "uploading $HDFS_PATH/$SAMPLE.bam to $DEST_DIR with s3-dist-cp..."
s3-dist-cp \
    --src $HDFS_PATH/$SAMPLE.bam \
    --dest $DEST_DIR/$SAMPLE.bam

echo "marking duplicate reads, sorting reads, and transforming $SAMPLE.bam to $SAMPLE.alignments.adam..."
adam-submit \
    --master yarn \
    --deploy-mode cluster \
    --driver-memory $DRIVER_MEMORY \
    --executor-memory $EXECUTOR_MEMORY \
    --conf spark.driver.cores=$DRIVER_CORES \
    --conf spark.executor.cores=$EXECUTOR_CORES \
    --conf spark.yarn.executor.memoryOverhead=2048 \
    -- \
    transformAlignments \
    -mark_duplicate_reads \
    -sort_reads \
    $HDFS_PATH/$SAMPLE.bam \
    $HDFS_PATH/$SAMPLE.alignments.adam

echo "uploading $HDFS_PATH/$SAMPLE.alignments.adam to $DEST_DIR with s3-dist-cp..."
s3-dist-cp \
    --src $HDFS_PATH/$SAMPLE.alignments.adam \
    --dest $DEST_DIR/$SAMPLE.alignments.adam

echo "calling variants on $SAMPLE.alignments.adam against reference $REFERENCE with avocado..."
avocado-submit \
    --master yarn \
    --deploy-mode cluster \
    --driver-memory $DRIVER_MEMORY \
    --executor-memory $EXECUTOR_MEMORY \
    --conf spark.driver.cores=$DRIVER_CORES \
    --conf spark.executor.cores=$EXECUTOR_CORES \
    --conf spark.yarn.executor.memoryOverhead=2048 \
    -- \
    biallelicGenotyper \
    -no_chr_prefixes \
    $HDFS_PATH/$SAMPLE.alignments.adam \
    $HDFS_PATH/$SAMPLE.avocado.genotypes.tmp.adam

echo "joint calling $SAMPLE.avocado.genotypes.tmp.adam to $SAMPLE.avocado.vcf.gz with avocado..."
avocado-submit \
    --master yarn \
    --deploy-mode cluster \
    --driver-memory $DRIVER_MEMORY \
    --executor-memory $EXECUTOR_MEMORY \
    --conf spark.driver.cores=$DRIVER_CORES \
    --conf spark.executor.cores=$EXECUTOR_CORES \
    --conf spark.yarn.executor.memoryOverhead=2048 \
    -- \
    jointer \
    -single \
    $HDFS_PATH/$SAMPLE.avocado.genotypes.tmp.adam \
    $HDFS_PATH/$SAMPLE.avocado.vcf.gz

echo "uploading $HDFS_PATH/$SAMPLE.avocado.vcf.gz to $DEST_DIR with s3-dist-cp..."
s3-dist-cp \
    --src $HDFS_PATH/$SAMPLE.avocado.vcf.gz \
    --dest $DEST_DIR/$SAMPLE.avocado.vcf.gz

echo "transforming $SAMPLE.avocado.vcf.gz to $SAMPLE.avocado.genotypes.adam..."a
adam-submit \
    --master yarn \
    --deploy-mode cluster \
    --driver-memory $DRIVER_MEMORY \
    --executor-memory $EXECUTOR_MEMORY \
    --conf spark.driver.cores=$DRIVER_CORES \
    --conf spark.executor.cores=$EXECUTOR_CORES \
    --conf spark.yarn.executor.memoryOverhead=2048 \
    -- \
    transformGenotypes \
    $HDFS_PATH/$SAMPLE.avocado.vcf.gz \
    $HDFS_PATH/$SAMPLE.avocado.genotypes.adam

echo "uploading $HDFS_PATH/$SAMPLE.genotypes.adam to $DEST_DIR with s3-dist-cp..."
s3-dist-cp \
    --src $HDFS_PATH/$SAMPLE.avocado.genotypes.adam \
    --dest $DEST_DIR/$SAMPLE.avocado.genotypes.adam

echo "transforming $SAMPLE.avocado.vcf.gz to $SAMPLE.avocado.variants.adam..."
adam-submit \
    --master yarn \
    --deploy-mode cluster \
    --driver-memory $DRIVER_MEMORY \
    --executor-memory $EXECUTOR_MEMORY \
    --conf spark.driver.cores=$DRIVER_CORES \
    --conf spark.executor.cores=$EXECUTOR_CORES \
    --conf spark.yarn.executor.memoryOverhead=2048 \
    -- \
    transformVariants \
    $HDFS_PATH/$SAMPLE.avocado.vcf.gz \
    $HDFS_PATH/$SAMPLE.avocado.variants.adam

echo "uploading $HDFS_PATH/$SAMPLE.variants.adam to $DEST_DIR with s3-dist-cp..."
s3-dist-cp \
    --src $HDFS_PATH/$SAMPLE.avocado.variants.adam \
    --dest $DEST_DIR/$SAMPLE.avocado.variants.adam

echo "cleaning up hdfs..."
hadoop fs -rm -r -skipTrash $HDFS_PATH/${SAMPLE}_1.fq.gz
hadoop fs -rm -r -skipTrash $HDFS_PATH/${SAMPLE}_2.fq.gz
hadoop fs -rm -r -skipTrash $HDFS_PATH/$SAMPLE.ifq
hadoop fs -rm -r -skipTrash $HDFS_PATH/$SAMPLE.bam
hadoop fs -rm -r -skipTrash $HDFS_PATH/$SAMPLE.alignments.adam
hadoop fs -rm -r -skipTrash $HDFS_PATH/$SAMPLE.avocado.vcf.gz
hadoop fs -rm -r -skipTrash $HDFS_PATH/$SAMPLE.avocado.genotypes.tmp.adam
hadoop fs -rm -r -skipTrash $HDFS_PATH/$SAMPLE.avocado.genotypes.adam
hadoop fs -rm -r -skipTrash $HDFS_PATH/$SAMPLE.avocado.variants.adam
