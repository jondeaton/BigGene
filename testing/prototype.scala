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


val fn = "/Users/jonpdeaton/Datasets/1000genomes/NA12878/little-subsampled.bam"
val rdd = sc.loadBam(fn)

val sqlContext = SQLContext.getOrCreate(rdd.rdd.context)
import sqlContext.implicits._

def score(record: AlignmentRecord): Int = {
    record.qualityScores.filter(15 <=).sum
}

// Makes a DataFrame mapping "recordGroupName" => "library"
def libraryDf(rgd: RecordGroupDictionary): DataFrame = {
  rgd.recordGroupMap.mapValues(value => {
    val (recordGroup, _) = value
    recordGroup.library
  }).toSeq.toDF("recordGroupName", "library")
}

val score5PrimeDf = rdd.dataset
  .filter(record => record.primaryAlignment.getOrElse(false))
  .map((record: sql.AlignmentRecord) => {
    val avroRecord = record.toAvro
    val r = RichAlignmentRecord(avroRecord)
    (record.recordGroupName, record.readName,
      score(avroRecord), r.fivePrimeReferencePosition.pos)
  }).toDF("recordGroupName", "readName", "score", "fivePrimePosition")

// Join in the scores, 5Prime positions and library
val fragmentKey = Seq("recordGroupName", "readName")
val df = rdd.dataset
  .join(score5PrimeDf, fragmentKey)
  .join(libraryDf(rdd.recordGroups), "recordGroupName")

// Get the score for each fragment by sum-aggregating the scores for each read
val fragmentScoresDf = df
  .filter($"primaryAlignment")
  .select($"recordGroupName", $"readName", $"score")
  .groupBy("recordGroupName", "readName")
  .agg(sum($"score").as("score"))

// read one positions
val readOnePosDf = df
  .select($"primaryAlignment", $"recordGroupName", $"readName", $"fivePrimePosition")
  .filter($"primaryAlignment" and $"readInFragment" === 0)
  .groupBy($"recordGroupName", $"readName")
  .agg(max($"fivePrimePosition").as("read1RefPos"))
  .drop($"primaryAlignment")

// read two positions
val readTwoPosDf = df
  .select($"primaryAlignment", $"recordGroupName", $"readName", $"fivePrimePosition")
  .filter($"primaryAlignment" and $"readInFragment" === 1)
  .groupBy($"recordGroupName", $"readName")
  .agg(max($"fivePrimePosition").as("read2RefPos"))
  .drop($"primaryAlignment")

// Score and reference positions per fragment
val posDf = readOnePosDf.join(readTwoPosDf, fragmentKey)
val fragDf = fragmentScoresDf.join(posDf, fragmentKey)

// window into all fragments at the same reference position (sorted by score)
val positionWindow = Window.partitionBy("read1RefPos", "read2RefPos", "library")
  .orderBy($"score".desc)

val fragsRankedDf = fragDf.withColumn("rank", row_number.over(positionWindow))

val markedFragsDf = fragsRankedDf
  .withColumn("duplicatedRead", fragsRankedDf("rank") =!= 1)
  .drop("rank")

// Join the fragment markings back to
val markedReadsDf = df.join(markedFragsDf, fragmentKey)
  .drop("fivePrimePosition", "read1RefPos", "read1RefPos")

// Convert back to RDD now that duplicates have been marked
markedReadsDf.as[sql.AlignmentRecord]
  .rdd.map(_.toAvro)

/* Not sure about this stuff down here...

// window into all mapped reads of the same fragment
val fragmentWindow = Window.partitionBy("recordGroupName", "readName", "library")
  .orderBy($"score".desc)
// rank reads by score and denote all but highest scoring per fragment as duplicates
val rankedDf = df.withColumn("rank", row_number.over(fragmentWindow))
val markedDf = df.withColumn("duplicateRead", rankedDf("rank") =!= 1).drop("rank")

val leftPositions = rdd.dataset.groupBy("recordGroupName", "readName", "library", "readInfragment")

// Filter for
val positionWindow = rdd.dataset.filter(('readMapped and 'primaryAlignment) or !'readMapped)

*/
