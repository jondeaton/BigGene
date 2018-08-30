import org.apache.spark.{SparkContext, SparkConf}
import org.apache.spark.sql.{Dataset, DataFrame, SQLContext}
import org.bdgenomics.adam.rdd.ADAMContext._
import org.bdgenomics.adam.models.{RecordGroupDictionary, ReferencePosition}
import org.apache.spark.sql.SparkSession
import spark.implicits._
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
import org.bdgenomics.adam.rdd.read.SingleReadBucket
import org.bdgenomics.adam.rdd.read._
import org.bdgenomics.adam.models.{RecordGroupDictionary, ReferencePosition}


val fn = "/home/jdeaton/Datasets/1000Genomes/NA12878/downsampled/little-subsampled.bam"
val alignmentRecords = sc.loadBam(fn)
val fragmentRdd = alignmentRecords.toFragments

import fragmentRdd.dataset.sparkSession.implicits._

def toFragmentSchema(fragment: Fragment, recordGroups: RecordGroupDictionary) = {

    def score(record: AlignmentRecord): Int = {
        record.qualityScores.filter(15 <=).sum
    }

    def scoreBucket(bucket: SingleReadBucket): Int = {
        bucket.primaryMapped.map(score).sum
    }

    val bucket = SingleReadBucket(fragment)
    val position = ReferencePositionPair(bucket)

    val recordGroupName: Option[String] = bucket.allReads.headOption.fold(None)(_.getRecordGroupName)
    val library = recordGroups(recordGroupName)

    val read1refPos = position.read1refPos
    val read2refPos = position.read2refPos

    (library , recordGroupName, fragment.getReadName,
    read1refPos.fold()(_.referenceName), read1refPos.fold()(_.pos), read1refPos.fold()(_.strand),
    read2refPos.fold()(_.referenceName), read2refPos.fold()(_.pos), read2refPos.fold()(_.strand),
    scoreBucket(bucket))
}

// convert fragments to dataframe wtih reference positions and scores
val df = fragmentRdd.rdd.map(toFragmentSchema(_, fragmentRdd.recordGroups))
    .toDF("library", "recordGroupName", "readName",
    "read1contigName", "read1fivePrimePosition", "read1strand",
    "read2contigName", "read2fivePrimePosition", "read2strand",
    "score")