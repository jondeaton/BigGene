#!/bin/bash
# This script runs duplicate marking using ADAM

# Input file
BAM="/usr/remote/share/workspace/jon/little-subsampled.bam"

# output file
MKDUPS="mkdups.bam"

#ADAM submission script location
adam_submit="adam/bin/adam-submit"
#adam_submit="axstreamADAM/bin/adam-submit" # Use this one if you cloned the axstreamADAM repository instead

# Set JAVA_OPTS to be able to load native libraries and to set heap size
JAVA_OPTS="$OUR_JAVA_OPTS"
JAVA_OPTS="$JAVA_OPTS -Djava.library.path=$SPARK_LIBRARY_PATH"
JAVA_OPTS="$JAVA_OPTS -Xms$SPARK_MEM -Xmx$SPARK_MEM"

export HADOOP_HOME="/opt/hadoop"
export HADOOP_OPTS="$HADOOP_OPTS -Djava.library.path=$HADOOP_HOME/lib/native"

# remove output and temporary files
rm -rf "$MKDUPS"
rm -r mkdups.bam_head mkdups.bam_tail mkdups.log

time $adam_submit \
    --name "Mark Duplicates" \
    --master "local[*]" \
    --conf 'spark.driver.memory=6g' \
    --conf 'spark.executor.memory=8g' \
    --conf 'spark.driver.extraJavaOptions=-Djava.library.path=/opt/hadoop/lib/native' \
    --conf 'spark.executor.extraJavaOptions=-Djava.library.path=/opt/hadoop/lib/native' \
    -- transformAlignments \
    "$BAM" "$MKDUPS" \
    -mark_duplicate_reads \
    -single 2>&1 \
    -sort_reads | tee mkdups.log

