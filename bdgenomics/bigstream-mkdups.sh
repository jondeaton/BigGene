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
SPARK_MEM=${SPARK_MEM:-6g}
export SPARK_MEM

# Set JAVA_OPTS to be able to load native libraries and to set heap size
JAVA_OPTS="$OUR_JAVA_OPTS"
JAVA_OPTS="$JAVA_OPTS -Djava.library.path=$SPARK_LIBRARY_PATH"
JAVA_OPTS="$JAVA_OPTS -Xms$SPARK_MEM -Xmx$SPARK_MEM"

bigstream="$HOME/opt/spark-bigstream"
spark_bigstream="$bigstream/spark-2.1.1-BIGSTREAM-bin-bigstream-spark-yarn-h2.7.2"

export LD_LIBRARY_PATH="$bigstream/libs"
export SPARK_HOME="$spark_bigstream"

rm -rf "$MKDUPS"

time $adam_submit \
    --name "Mark Duplicates" \
    --master "local[*]" \
    --conf spark.bigstream.accelerate=true \
    --driver-memory 5g \
    --conf  spark.bigstream.qfe.optimizationSelectionPolicy=disableUDFs:disableHadoopPartitioning:disableNestedSchema:blacklistedOperators=InMemoryScan \
    -- transformAlignments \
    "$BAM" "$MKDUPS" \
    -mark_duplicate_reads \
    -sort_reads 2>&1 | tee mkdups.log

