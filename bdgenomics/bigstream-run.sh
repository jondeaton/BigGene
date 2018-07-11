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
log_file="bigstream-avocado.log"

rm -r "$variants_out"
rm "$log_file"

bigstream="$HOME/opt/spark-bigstream"
spark_bigstream="$bigstream/spark-2.1.1-BIGSTREAM-bin-bigstream-spark-yarn-h2.7.2"

export LD_LIBRARY_PATH="$bigstream/libs"
export SPARK_HOME="$spark_bigstream"

avocado/bin/avocado-submit \
    --master local[*] \
    --conf spark.bigstream.accelerate=true \
    --driver-memory 5g \
    --conf  spark.bigstream.qfe.optimizationSelectionPolicy=disableUDFs:disableHadoopPartitioning:disableNestedSchema:blacklistedOperators=InMemoryScan \
    -- biallelicGenotyper "$alignment" "$variants_out" 2>&1 | tee "$log_file"
