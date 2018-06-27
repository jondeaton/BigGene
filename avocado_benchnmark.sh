#!/bin/sh
# ADAM Benchmarking 

set -e # Exit if error occurs

bam="/home/jdeaton/Datasets/1000Genomes/bam/HG00096.mapped.ILLUMINA.bwa.GBR.low_coverage.20120522.bam"
bam="$HOME/Datasets/1000Genomes/NA12892/NA12892_S1.bam"

# Duplicate Marking
adam-submit \
	-- transformAlignments \
	"$bam" \
	mkdups.adam \
	-mark_duplicate_reads

# Fragment Duplicate Marking command
adam-submit \
	--master yarn \
	--deploy-mode cluster \
	--num-executors ${executors} \
	--executor-memory 200g \
	--executor-cores 32 \
	--driver-memory 64g \
	--conf spark.dynamicAllocation.enabled=false \
	--conf spark.driver.maxResultSize=0 \
	--conf spark.yarn.executor.memoryOverhead=8192 \
	--conf spark.kryo.registrationRequired=true \
	--conf spark.kryoserializer.buffer.max=1024m \
	--packages org.apache.parquet:parquet-avro:1.8.2 \
	-- transformFragments \
	frag.adam \
	mkdups.adam \
	-mark_duplicate_reads

# Base Quality Score Recalibration
adam-submit \
	--master yarn \
	--deploy-mode cluster \
	--num-executors ${executors} \
	--executor-memory 200g \
	--executor-cores 32 \
	--driver-memory 64g \
	--conf spark.dynamicAllocation.enabled=false \
	--conf spark.driver.maxResultSize=0 \
	--conf spark.yarn.executor.memoryOverhead=8192 \
	--conf spark.kryo.registrationRequired=true \
	--conf spark.kryoserializer.buffer.max=1024m \
	--packages org.apache.parquet:parquet-avro:1.8.2 \
	-- transformAlignments \
	aln.adam \
	bqsr.adam \
	-recalibrate_base_qualities \
	-known_snps dbsnp.adam

# INDEL Realignment
adam-submit \
	--master yarn \
	--deploy-mode cluster \
	--num-executors ${executors} \
	--executor-memory 200g \
	--executor-cores 32 \
	--driver-memory 64g \
	--conf spark.dynamicAllocation.enabled=false \
	--conf spark.driver.maxResultSize=0 \
	--conf spark.yarn.executor.memoryOverhead=8192 \
	--conf spark.kryo.registrationRequired=true \
	--conf spark.kryoserializer.buffer.max=1024m \
	--packages org.apache.parquet:parquet-avro:1.8.2 \
	-- transformAlignments \
	aln.adam \
	ri.adam \
	-realign_indels \
	-aligned_read_predicate \
	-max_consensus_number 32 \
	-max_reads_per_target 256 \
	-max_target_size 2048 \
	-limit_projection \
	-reference reference.fa \
	-log_odds_threshold 0.5

# Avocado Biallelic Genotyper
avocado-submit \
	--master yarn \
	--deploy-mode cluster \
	--num-executors ${executors} \
	--executor-memory 216g \
	--executor-cores 32 \
	--driver-memory 216g \
	--conf spark.dynamicAllocation.enabled=false \
	--conf spark.driver.maxResultSize=0 \
	--conf spark.yarn.executor.memoryOverhead=16384 \
	--conf spark.akka.frameSize=1024 \
	--conf spark.rpc.askTimeout=300 \
	--conf spark.kryoserializer.buffer.max=2047m \
	--conf spark.sql.shuffle.partitions=880 \
	--packages org.apache.parquet:parquet-avro:1.8.2 \
	-- biallelicGenotyper \
	aln.adam \
	gt.adam \
	-print_metrics \
	-is_not_grc \
	-min_genotype_quality 10 \
	-min_phred_to_discover_variant 15 \
	-min_observations_to_discover_variant 3 \
	-min_het_indel_quality_by_depth -1.0 \
	-min_hom_indel_quality_by_depth -1.0 \
	-min_het_indel_allelic_fraction 0.2 \
	-min_het_snp_allelic_fraction 0.125 \
	-max_het_snp_allelic_fraction 0.8 \131
	-max_het_indel_allelic_fraction 0.85 \
	-min_indel_rms_mapping_quality 30 \
	-min_het_snp_quality_by_depth 2.5 \
	-max_het_indel_allelic_fraction 0.7
