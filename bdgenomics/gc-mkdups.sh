#!/bin/bash
# This script submits a duplicate marking job to Google Cloud Dataproc
# You will need to jave the jar: "google-cloud-nio-0.22.0-alpha-shaded.jar"
# downloaded from this link and in the directory in which this file exists
# http://central.maven.org/maven2/com/google/cloud/google-cloud-nio/0.22.0-alpha/
# You will also need to have the adam repository in this same directory
# You will probably also need to change the name of the cluster that you 
# submit to

ADAM_DIR="adam"
ADAM_MAIN="org.bdgenomics.adam.cli.ADAMMain"
ADAM_CLI_JAR=$(${ADAM_DIR}/bin/find-adam-assembly.sh)
GC_NIO_JAR="google-cloud-nio-0.22.0-alpha-shaded.jar"

gcloud dataproc jobs submit spark \
  --cluster="bdgenomics-tester" \
  --region="asia-east1" \
  --class="$ADAM_MAIN" \
  --jars="$ADAM_CLI_JAR,$GC_NIO_JAR" \
  --properties 'spark.serializer=org.apache.spark.serializer.KryoSerializer,spark.kryo.registrator=org.bdgenomics.adam.serialization.ADAMKryoRegistrator' \
  -- \
  transformAlignments \
  $1 $2 \
  -mark_duplicate_reads \
  -single \
  -sort_reads
