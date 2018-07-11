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
variants_out="tmp.adam"

rm -r "$variants_out"

avocado/bin/avocado-submit \
    --master "local[*]" \
    --conf spark.logLineage=true \
    --conf spark.driver.extraJavaOptions=-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=5005 \
    --conf spark.driver.extraClassPath=$HOME/repos/BigGene/bdgenomics/spark_changes/target/spark-changes-2.1.1-7.jar \
    --conf spark.network.timeout=100000000 \
    --conf spark.eventLog.enabled=true \
    -- biallelicGenotyper "$alignment" "$variants_out" 2>&1
