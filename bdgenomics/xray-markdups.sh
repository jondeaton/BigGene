#!/bin/bash

# Intermediate files (and output)
#fn="little-subsampled.bam"
fn="10000000-NA12878_phased_possorted_bam.bam"
BAM="$HOME/Datasets/1000Genomes/NA12878/downsampled/$fn"
MKDUPS="mkdups.bam"

#ADAM/Avocado setup
adam_submit="../bdgenomics/adam/bin/adam-submit"
avocado_submit="../bdgenomics/avocado/bin/avocado-submit"

# Set SPARK_MEM if it isn't already set since we also use it for this process
SPARK_MEM=${SPARK_MEM:-8g}
export SPARK_MEM

# Set JAVA_OPTS to be able to load native libraries and to set heap size
JAVA_OPTS="$OUR_JAVA_OPTS"
JAVA_OPTS="$JAVA_OPTS -Djava.library.path=$SPARK_LIBRARY_PATH"
JAVA_OPTS="$JAVA_OPTS -Xms$SPARK_MEM -Xmx$SPARK_MEM"

echo -e  "Using X-Ray"
xray_dir="xray"
XRAY_FLAGS="--conf spark.bigstream.xray.overwrite=true"
XRAY_FLAGS="$XRAY_FLAGS --conf spark.bigstream.xray.dir=$xray_dir"
XRAY_FLAGS="$XRAY_FLAGS --conf spark.extraListeners=org.apache.spark.bigstream.xray.AXBDXrayListener"
XRAY_FLAGS="$XRAY_FLAGS --conf spark.driver.extraClassPath=spark-bigstream-xray-1.0.3-BIGSTREAM.jar"
xray_extension="xray-log"

echo "$XRAY_FLAGS"
rm -rf "$MKDUPS"

time $adam_submit \
    --conf spark.bigstream.xray.overwrite=true \
    --conf spark.bigstream.xray.filename=xray_log \
    --conf spark.bigstream.xray.dir=xray \
    --conf spark.extraListeners=org.apache.spark.bigstream.xray.AXBDXrayListener \
    --conf spark.driver.extraClassPath=spark-bigstream-xray-1.0.3-BIGSTREAM.jar \
    --name "Mark Duplicates" \
    --master "local[*]" \
    --driver-memory 6g \
    -- transformAlignments \
    "$BAM" "$MKDUPS" \
    -mark_duplicate_reads \
    -single 2>&1 | tee mkdups.log


