#!/bin/sh
# Genome Analysis Tool Kit (GATK) benchmarking pipeline

# bam_file="/home/jdeaton/Datasets/1000Genomes/NA12892/NA12892_S1.bam"
bam_file="/home/jdeaton/Desktop/HG00096.mapped.ILLUMINA.bwa.GBR.low_coverage.20120522.bam"
executors=4

set -e # Exit if error occurs

# Duplicate Marking
gatk MarkDuplicatesSpark --input "$bam_file" \
	--output "md.bam" \

# Base Quality Score Recalibration (Generation)
gatk BaseRecalibratorSpark --input "md.bam" \
	--output table \
	--known-sites dbsnp.vcf \
	--reference reference.2bit \

# Base Quality Score Recalibration (Application)
gatk ApplyBQSRSpark --input "$bam_file" \
	--bqsr_recal_file tables \
	--output bqsr.bam \
	--shardedOutput true \
	-- \
	--driver-memory 64g \
	--executor-cores 32 --executor-memory 200g \
	--sparkRunner SPARK --sparkMaster yarn --deploy-mode cluster \
	--conf spark.dynamicAllocation.enabled=false \
	--num-executors ${executors}

# Haplotype Calling
gatk HaplotypeCallerSpark --input "$bam_file" \
	--output hc.vcf \
	--reference reference.2bit \
	--shardedOutput true \
	-VS LENIENT \
	-- \
	--driver-memory 64g \
	--executor-cores 32 --executor-memory 200g \
	--sparkRunner SPARK --sparkMaster yarn --deploy-mode cluster \
	--conf spark.dynamicAllocation.enabled=false \
	--num-executors ${executors}
