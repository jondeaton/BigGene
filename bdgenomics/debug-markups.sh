#!/bin/bash

# Intermediate files (and output)
BAM="$HOME/Datasets/1000genomes/NA12878/little-subsampled.bam"
MKDUPS="mkdups.bam"

#ADAM/Avocado setup
adam_submit="../bdgenomics/adam/bin/adam-submit"
avocado_submit="../bdgenomics/avocado/bin/avocado-submit"

# Set SPARK_MEM if it isn't already set since we also use it for this process
SPARK_MEM=${SPARK_MEM:-6g}
export SPARK_MEM

# Set JAVA_OPTS to be able to load native libraries and to set heap size
JAVA_OPTS="$OUR_JAVA_OPTS"
JAVA_OPTS="$JAVA_OPTS -Djava.library.path=$SPARK_LIBRARY_PATH"
JAVA_OPTS="$JAVA_OPTS -Xms$SPARK_MEM -Xmx$SPARK_MEM"

rm -rf "$MKDUPS"

$adam_submit \
    --master "local[*]" \
    --conf spark.logLineage=true \
    --conf spark.driver.extraJavaOptions=-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=5005 \
    --conf spark.network.timeout=100000000 \
    --driver-memory 5g \
    -- transformAlignments \
    "$BAM" "$MKDUPS" \
    -mark_duplicate_reads \
    -sort_reads 2>&1
