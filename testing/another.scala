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


df
.filter('readName === "HWI-D00684:221:HNWKCADXX:1:1109:19666:39303")
.groupBy("recordGroupName", "readName")
.agg(first(when('primaryAlignment and 'readInFragment === 0, 'fivePrimePosition)) as 'read1RefPos)