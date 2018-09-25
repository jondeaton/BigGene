#!/bin/bash
# This script runs duplicate marking using ADAM

#ADAM submission script location
adam_submit="adam/bin/adam-submit"

# Set JAVA_OPTS to be able to load native libraries and to set heap size
JAVA_OPTS="$JAVA_OPTS -Djava.library.path=$SPARK_LIBRARY_PATH"
JAVA_OPTS="$JAVA_OPTS -Xms$SPARK_MEM -Xmx$SPARK_MEM"

time $adam_submit \
    --name "Mark Duplicates" \
    --master "local[*]" \
    --conf 'spark.driver.memory=6g' \
    --conf 'spark.executor.memory=8g' \
    -- transformAlignments \
    $1 $2 \
    -mark_duplicate_reads \
    -single 2>&1 \
    -sort_reads | tee mkdups.log

