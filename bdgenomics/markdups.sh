#!/usr/bin/env bash
# This script is for running the PCR duplicate marking algorithm in different ways

# =========================
# Options. Because parsing command line arguments in Bash is nosogood


if [ $# -eq 0 ]
  then
    input_filename="$HOME/Datasets/1000Genomes/NA12878/downsampled/little-subsampled.bam"
    # took 12m39.653s on Spark SQL version, theirs took 27m19.691s
    # input_filename="$HOME/Datasets/1000Genomes/NA12878/downsampled/20000000-NA12878_phased_possorted_bam.bam"
else
    input_filename="$1"
fi

output_filename="mkdups.bam"
log_file="mkdups.log"

debug=false         # Pauses execution so that you can attach IntelliJ Debugger
bigstream=false     # Run with Bigstream Spark
xray=false          # Run with X-ray (cannot use Bistream Spark)
fragments=false     # Input are fragments

xray_file="mkdups.xray-log"

# =========================

#ADAM/Avocado locations
#adam_submit="axstreamADAM/bin/adam-submit"
adam_submit="adam/bin/adam-submit"
avocado_submit="avocado/bin/avocado-submit"

if "$fragments"; then
    adam_command="transformFragments"
else
    adam_command="transformAlignments"
fi

if "$bigstream"; then
  echo -e  "._:=** Using Bigstream acceleration **=:_."
  bigstream_home="$HOME/opt/spark-bigstream"
  spark_bigstream="$bigstream_home/spark-2.1.1-BIGSTREAM-bin-bigstream-spark-yarn-h2.7.2"
  export LD_LIBRARY_PATH="$bigstream_home/libs"
  export SPARK_HOME="$spark_bigstream"
fi

if "$xray"; then
    echo -e  "Using X-Ray"
    xray_dir="xray"
    XRAY_FLAGS="--conf spark.bigstream.xray.overwrite=true"
    XRAY_FLAGS="$XRAY_FLAGS --conf spark.bigstream.xray.dir=$xray_dir"
    XRAY_FLAGS="$XRAY_FLAGS --conf spark.extraListeners=org.apache.spark.bigstream.xray.AXBDXrayListener"
    XRAY_FLAGS="$XRAY_FLAGS --conf spark.driver.extraClassPath=spark-bigstream-xray-1.0.3-BIGSTREAM.jar"
fi

if "$debug"; then
    echo -e "Debugging"
    DEBUG_FLAGS="spark.network.timeout=100000000"
    DEBUG_FLAGS="$DEBUG_FLAGS spark.driver.extraJavaOptions=-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=5005"
fi

JAVA_OPTS="$JAVA_OPTS -Djava.library.path=$SPARK_LIBRARY_PATH"
JAVA_OPTS="$JAVA_OPTS -Xms$SPARK_MEM -Xmx$SPARK_MEM"

export HADOOP_HOME="/opt/hadoop"
HADOOP_NATIVE="$HADOOP_HOME/lib/native"
export HADOOP_OPTS="$HADOOP_OPTS -Djava.library.path=$HADOOP_NATIVE"

# Remove anything from previous runs
rm -rf "$output_filename" $output_filename"_head" $output_filename"_tail" "$log_file"

# Run Duplicate Marking
time $adam_submit \
    --name "Mark Duplicates" \
    --master "local[*]" \
    --conf 'spark.driver.memory=6g' \
    --conf 'spark.executor.memory=8g' \
    --conf "spark.driver.extraJavaOptions=-Djava.library.path=$HADOOP_NATIVE" \
    --conf "spark.executor.extraJavaOptions=-Djava.library.path=$HADOOP_NATIVE" \
    --conf spark.bigstream.accelerate="$bigstream" \
    "$DEBUG_FLAGS" "$XRAY_FLAGS" --conf spark.bigstream.xray.filename="$xray_file" \
    -- transformAlignments \
    "$input_filename" "$output_filename" \
    -mark_duplicate_reads \
    -single \
    -sort_reads 2>&1 | tee "$log_file"

