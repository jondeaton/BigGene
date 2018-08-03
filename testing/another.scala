import org.apache.spark.{SparkContext, SparkConf}
import org.apache.spark.sql.{Dataset, DataFrame, SQLContext}
import org.bdgenomics.adam.rdd.ADAMContext._
import org.bdgenomics.adam.models.{RecordGroupDictionary, ReferencePosition}
import org.apache.spark.sql.SparkSession
val sparkSession = SparkSession.builder.master("local").appName("test").getOrCreate()
import sparkSession.implicits._
import org.apache.spark.sql.expressions.Window
import org.bdgenomics.adam.rich.RichAlignmentRecord
import org.bdgenomics.formats.avro.{AlignmentRecord, Fragment}
import org.bdgenomics.adam.sql
import scala.collection.immutable.StringLike
import scala.math
import htsjdk.samtools.{ Cigar, CigarElement, CigarOperator, TextCigarCodec }
import scala.collection.JavaConversions._
import org.apache.spark.sql.functions
import org.bdgenomics.formats.avro.{ AlignmentRecord, Strand }


val fn = "/home/jdeaton/Datasets/1000Genomes/NA12878/downsampled/little-subsampled.bam"
val alignmentRecords = sc.loadBam(fn)

val sqlContext = SQLContext.getOrCreate(alignmentRecords.rdd.context)
import sqlContext.implicits._

// Makes a DataFrame mapping "recordGroupName" => "library"
def libraryDf(rgd: RecordGroupDictionary): DataFrame = {
  rgd.recordGroupMap.mapValues(value => {
    val (recordGroup, _) = value
    recordGroup.library
  }).toSeq.toDF("recordGroupName", "library")
}

// UDF for calculating score of a read
val scoreUDF = functions.udf((qual: String) => {
  qual.toCharArray.map(q => q - 33).filter(15 <=).sum
})

import scala.math

def isClipped(el: CigarElement): Boolean = {
  el.getOperator == CigarOperator.SOFT_CLIP || el.getOperator == CigarOperator.HARD_CLIP
}

def fivePrimePosition(readMapped: Boolean,
                      readNegativeStrand: Boolean, cigar: String,
                      start: Long, end: Long): Long = {
  if (!readMapped) 0L
  else {
    val samtoolsCigar = TextCigarCodec.decode(cigar)
    val cigarElements = samtoolsCigar.getCigarElements
    math.max(0L,
      if (readNegativeStrand) {
        cigarElements.reverse.takeWhile(isClipped).foldLeft(end)({
          (pos, cigarEl) => pos + cigarEl.getLength
        })
      } else {
        cigarElements.takeWhile(isClipped).foldLeft(start)({
          (pos, cigarEl) => pos - cigarEl.getLength
        })
      })
  }
}

val fpUDF = functions.udf((readMapped: Boolean, readNegativeStrand: Boolean, cigar: String,
  start: Long, end: Long) => fivePrimePosition(readMapped, readNegativeStrand, cigar, start, end))

// 1. Find 5' positions for all reads
val df = alignmentRecords.dataset
  .withColumn("fivePrimePosition",
    fpUDF('readMapped, 'readNegativeStrand, 'cigar, 'start, 'end))


val positionedDf = df
    .groupBy("recordGroupName", "readName")
    .agg(

      // Read 1 Reference Position
      first(when('primaryAlignment and 'readInFragment === 0,
        when('readMapped, 'contigName).otherwise('sequence)),
        ignoreNulls = true)
        as 'read1contigName,

      first(when('primaryAlignment and 'readInFragment === 0,
        when('readMapped, 'fivePrimePosition).otherwise(0L)),
        ignoreNulls = true)
        as 'read1fivePrimePosition,

      first(when('primaryAlignment and 'readInFragment === 0,
        when('readMapped,
          when('readNegativeStrand, Strand.REVERSE.toString).otherwise(Strand.FORWARD.toString))
          .otherwise(Strand.INDEPENDENT.toString)),
        ignoreNulls = true)
        as 'read1strand,

      // Read 2 Reference Position
      first(when('primaryAlignment and 'readInFragment === 1,
        when('readMapped, 'contigName).otherwise('sequence)),
        ignoreNulls = true)
        as 'read2contigName,

      first(when('primaryAlignment and 'readInFragment === 1,
        when('readMapped, 'fivePrimePosition).otherwise(0L)),
        ignoreNulls = true)
        as 'read2fivePrimePosition,

      first(when('primaryAlignment and 'readInFragment === 1,
        when('readMapped,
          when('readNegativeStrand, Strand.REVERSE.toString).otherwise(Strand.FORWARD.toString))
          .otherwise(Strand.INDEPENDENT.toString)),
        ignoreNulls = true)
        as 'read2strand,

      sum(when('readMapped and 'primaryAlignment, scoreUDF('qual))) as 'score)
    .join(libraryDf(alignmentRecords.recordGroups), "recordGroupName")

// positionedDf.count = 514,303
val positionWindow = Window
  .partitionBy('library,
    'read1contigName, 'read1fivePrimePosition, 'read1strand,
    'read2contigName, 'read2fivePrimePosition, 'read2strand)
  .orderBy('score.desc)

// Unmapped reads
val filteredDf = positionedDf.filter('read1fivePrimePosition.isNotNull) // count = 232,860 (not anymore)


positionedDf.filter('read1contigName === "chr1" and 'read1fivePrimePosition === 17311987 and 'read1strand === "FORWARD" and
'read2contigName === "chr1" and 'read2fivePrimePosition === 17312190 and 'read2strand === "REVERSE")

