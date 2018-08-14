/*
Notes on starting Spark History

1. Need to make sure that you have the following in /path/to/spark/conf/spark-defaults.conf
spark.eventLog.enabled true
spark.eventLog.dir /path/to/spark/logs
spark.history.fs.logDirectory /path/to/spark/logs
*/

// Some sable scala code
import org.apache.spark.sql.SparkSession
import spark.implicits._
import org.apache.spark.sql.functions

// sample
val df = spark.createDataFrame(Seq(
      (7369, "SMITH", "CLERK", 7902, "17-Dec-80", 800, 20, 10),
      (7499, "ALLEN", "SALESMAN", 7698, "20-Feb-81", 1600, 300, 30),
      (7521, "WARD", "SALESMAN", 7698, "22-Feb-81", 1250, 500, 30),
      (7566, "JONES", "MANAGER", 7839, "2-Apr-81", 2975, 0, 20),
      (7654, "MARTIN", "SALESMAN", 7698, "28-Sep-81", 1250, 1400, 30),
      (7698, "BLAKE", "MANAGER", 7839, "1-May-81", 2850, 0, 30),
      (7782, "CLARK", "MANAGER", 7839, "9-Jun-81", 2450, 0, 10),
      (7788, "SCOTT", "ANALYST", 7566, "19-Apr-87", 3000, 0, 20),
      (7839, "KING", "PRESIDENT", 0, "17-Nov-81", 5000, 0, 10),
      (7844, "TURNER", "SALESMAN", 7698, "8-Sep-81", 1500, 0, 30),
      (7876, "ADAMS", "CLERK", 7788, "23-May-87", 1100, 0, 20)
    )).toDF("empno", "ename", "job", "mgr", "hiredate", "sal", "comm", "deptno")

case class Employee(empno: Int, ename: String,
      job: String, mgr: Int, hiredate: String,
      sal: Int, comm: Int, deptno: Int)

// maximum by salary
df.groupBy("job").agg(max("sal")).show

// Window thing
val jobWin = Window.partitionBy("job")
df.withColumn("mvp", max("sal").over(Window.partitionBy("job")))

df.withColumn("mvp", max(df("sal")).over(Window.partitionBy("job")))


case class Person




// Read this: http://web.stanford.edu/class/cs145/lectures/lecture-9/review.pdf
// https://en.wikipedia.org/wiki/Curry%E2%80%93Howard_correspondence