---
title: 
- ADAM/Avocado Architecture
author:
- Jon Deaton
date:
- Thursday, July 5, 2018
theme: 
- Copenhagen
---

[//]: # (https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3198575/pdf/btr509.pdf)

[//]: # (pandoc presentation.md -t beamer -o final.pdf)

# Topics

+ ADAM/Avocado Schemas & Class heigherarchy
+ Biallectic Genotyper Execution (variant calling)
  - Cannonical SNP caller algorithm
+ Read Alignment Execution (read mapping)

# ADAM Schemas Heigherarchy

![Genomic RDD class Heigherarchy](GenomicRDD.png){ width=100% }

- GenomicRDD = abstract wrapper for genomic datasets.
- GenomicRDD wraps Spark RDD *and* **Spark SQL DataFrame**
    + Single class provides abstraction of both representations
- ADAMContext loads GenomicsRDDs to manipulate

# bdg-formats schemas

ADAM provides several schemas convenient for representing genomic data

- *AlignmentRecord schema* - represents a genomic read & that read’s alignment to a reference genome.
- *Feature schema* - represents a generic genomic feature. Annorate a genomic region annotation, (e.g. coverage observed over that region, or the coordinates of an exon) .
- *Fragment schema* - represents a set of read alignments that came from a single sequenced fragment.
- *Genotype schema* - represents a genotype call, along with annotations/quality/read support of called genotype.
- *NucleotideContigFragment schema* represents a section of a contig’s sequence.
- *Variant schema* - represents a sequence variant & statistics across samples (indivisuals) and annoration on effect.

# GenomicRDD

	trait GenomicDataset[T, U <: Product,
	 V <: GenomicDataset[T, U, V]] {

	  // These data as a Spark SQL Dataset.
	  val dataset: Dataset[U]

	  // The RDD of genomic data that we are wrapping
	  val rdd: RDD[T]

	  // This data as a Spark SQL DataFrame
	  def toDF(): DataFrame = {
	    dataset.toDF()
	  }

	  ...
	}


# Avocado Biallelic Genotyper Call Graph

Example usage:
		avocado-submit -- biallelicGenotyper in.bam out.adam

1. `loadAlignments`
	- From BAM/FASTQ/ADAM/Parquet file format
2. `Prefilter Reads`
	- Autosome (non-sex), sex chromosome, mitochondrial (by name)
	- Mapped reads, high enough quality reads, mapped duiplicates
3. `DiscoverVariants` ($\sim 8$ seconds)
4. `CallVariants`  ($\sim 15$ seconds)


# `DiscoverVariants`

Discover all of the variants that exist in an RDD of reads, i.e. `RDD[AlignmentRecord]`

1.  Map `variantsInRead` over the `RDD[AlignmentRecord]`
	- `variantRdd = rdd.flatMap(variantsInRead)`
	- `variantsInRead` loops over CIGAR `string` in each `AlignmentRecord`
		+ CIGAR `string` was created during alignment
		+ `"42M5D56M"` = "$42$ matchnig, $5$ deleted bases,$56$ matchnig"
		+ Emits a stream of variants for each CIGAR `string`
2. Convert `variantsInRead` (RDD) to Dataframe

# `DiscoverVariants` continued...

3. Find unique variants (Dataframe SQL operation)

		val uniqueVariants = optMinObservations.fold({
			variantDs.distinct
		})(mo => {
			variantDs.groupBy(variantDs("contigName"),
			variantDs("start"),
			variantDs("referenceAllele"),
			variantDs("alternateAllele"))
			.count()
			.where($"count" > mo)
			.drop("count")
		})

4. Convert Dataframe back to RDD
	
		uniqueVariants.as[DiscoveredVariant]
			.rdd.map(_.toVariant)

# Avocado SNP Algorithm

- *Biallelic Variant Calling*
	+ **biallelic** genomic locus - site where only two alleles are observed
	+ **multiallelic** genomic locus - site where many alleles are observed

- The statistical algorithm used to "call variants" in Avocado (i.e. the business-end of Avocado)

+ Originally implemented and used in GATK and SAMtools
+ First presented in:"A statistical framework for SNP calling, mutation discovery, association mapping and population genetical parameter
estimation from sequencing data" Heng Li, Bioinformatics 2011 Nov 1;27(21):2987-93. doi: 10.1093/bioinformatics/btr509.
+ Deals with calling variants under sequencing error rates

# Variant calling theoretical foundations

+ *Site independency*: Data at different sites in the genome are independent. 
+ *Error independency and sample independency*: For a given genomic site, sequencing and mapping errors from different reads are independent.

$$ \mathcal{L}(\theta) = \prod_{i=1}^n \mathcal{L}_i (\theta) $$

+ $\mathcal{L}(\theta) =$ likelihood of all $n$ individuals/samples
+ $\mathcal{L}_i(\theta) =$ likelihood of the $i$'th sample 


# Computing genotype likelihoods

The likelihood that an individual has genotype $g$ is given by

$$ \mathcal{L}(g) = \frac{1}{m^k} \prod_{j=1}^l \bigg[ (m-g) \epsilon_j + g(1 - \epsilon_j) \bigg]\prod_{j=l+1}^k \bigg[ (m-g) (1- \epsilon_j) + g\epsilon_j \bigg] $$

- $m$ "ploidy of the sample", i.e. the number of alleles of that locus in the individual
- $g=$ the "genotype", i.e. the number of those alleles which are of the reference
- $\epsilon_j=$ sequencing error for base pair at position $j$
- $k=$ number of reads of that locus

# SNP Calling

With the probability of each genotype, $\mathcal{L}(g)$, in hand we let our genotype call $G$ as

$$G = \text{argmax}_g \mathcal{L}(g) $$

and the conficence be difference between the two likeliest genotypes.


# `CallVariants`: join reads against variants

1. Join reads against `DiscoveredVariants` ($\sim 1$ second)
2. Score putative variants, converts to `Observation`
3. 

# `CallVariants`: join reads against variants

Step 1: Join two RDDs

	val joinedRdd = TreeRegionJoin.joinAndGroupByRight(
		variants.rdd.keyBy(v => ReferenceRegion(v)),
	    reads.rdd.flatMap(r => {
	    ReferenceRegion.opt(r).map(rr => (rr, r))
	})).map(_.swap)


# `CallVariants`: score variants and get observations (`readsToObservations`)

1. Convert to `Observation` via `flatMap` and convert to Dataframe
2. Generate Dataframe of `ScoredObservations` calculating log-likelihood of genotypes

	$$\text{max}_g \ \text{log} \ \mathcal{L}(g) $$

3. Join variant and scoring tables, aggregating
	
4. Convert back to Dataset, then to RDD
5. Filter variants

