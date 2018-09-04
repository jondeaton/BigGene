#!/bin/bash

# Intermediate files (and output)
fn="little-subsampled.bam"
BAM="$HOME/Datasets/1000Genomes/NA12878/downsampled/$fn"
MKDUPS="mkdups.bam"

#ADAM/Avocado setup
adam_submit="../bdgenomics/adam/bin/adam-submit"
avocado_submit="../bdgenomics/avocado/bin/avocado-submit"

# Set JAVA_OPTS to be able to load native libraries and to set heap size
JAVA_OPTS="$OUR_JAVA_OPTS"
JAVA_OPTS="$JAVA_OPTS -Djava.library.path=$SPARK_LIBRARY_PATH"
JAVA_OPTS="$JAVA_OPTS -Xms$SPARK_MEM -Xmx$SPARK_MEM"

export HADOOP_HOME="/opt/hadoop"
export HADOOP_OPTS="$HADOOP_OPTS -Djava.library.path=$HADOOP_HOME/lib/native"

rm -rf "$MKDUPS"

$adam_submit \
    --name "Debug Mark Duplicates" \
    --master "local[*]" \
    --conf spark.logLineage=true \
    --conf spark.driver.extraJavaOptions=-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=5005 \
    --conf spark.network.timeout=100000000 \
    --conf spark.driver.memory=6g \
    --conf spark.executor.memory=8g \
    -- transformAlignments \
    "$BAM" "$MKDUPS" \
    -mark_duplicate_reads \
    -single \
    -sort_reads