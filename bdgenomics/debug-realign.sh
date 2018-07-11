#!/bin/sh

# Set JAVA_OPTS to be able to load native libraries and to set heap size
JAVA_OPTS="$OUR_JAVA_OPTS"
JAVA_OPTS="$JAVA_OPTS -Djava.library.path=$SPARK_LIBRARY_PATH"
JAVA_OPTS="$JAVA_OPTS -Xms$SPARK_MEM -Xmx$SPARK_MEM"

# Set SPARK_MEM if it isn't already set since we also use it for this process
SPARK_MEM=${SPARK_MEM:-6g}
export SPARK_MEM
JAVA_OPTS="$JAVA_OPTS -Xms$SPARK_MEM -Xmx$SPARK_MEM"

alignment="$HOME/Datasets/1000Genomes/NA12878/scratch/NA12878.algn.adam"
bsqr="$HOME/Datasets/1000Genomes/NA12878/scratch/NA12878.bsqr.adam"
realign="realign.tmp.adam"

rm -rf "$realign"

adam/bin/adam-submit \
    --master "local[*]" \
    --conf spark.logLineage=true \
    --conf spark.driver.extraJavaOptions=-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=5005 \
    --conf spark.network.timeout=100000000 \
    --driver-memory 5g \
    -- transformAlignments \
    "$bsqr" "$realign" \
    -realign_indels \
    -aligned_read_predicate \
    -max_consensus_number 32 \
    -max_reads_per_target 256 \
    -max_target_size 2048 \
    -limit_projection \
    -log_odds_threshold 0.5


