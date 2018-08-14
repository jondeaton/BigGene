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
val employees = sparkSession.createDataFrame(Seq(
      (7369, "Smith", "Clerk", 		"male", 	7902, "17-Dec-80", 	800, 20, 10),
      (7499, "Alexa", "Salesman", 	"female", 	7698, "20-Feb-81", 	1600, 300, 30),
      (7521, "Ward", "Salesman", 	"male",	   	7698, "22-Feb-81", 	1250, 500, 30),
      (7566, "Janice", "Manager", 	"female",	7839, "2-Apr-81",  	2975, 0, 20),
      (7654, "Martin", "Manager", 	"male",		7698, "28-Sep-81", 	1250, 1400, 30),
      (7698, "Becky", "MANAGER", 	"female", 	7839, "1-May-81", 	2850, 0, 30),
      (7782, "Clark", "Manager", 	"male",		7839, "9-Jun-81", 	2450, 0, 10),
      (7788, "Stephanie", "ANALYST","female",	7566, "19-Apr-87", 	3000, 0, 20),
      (7839, "Queen", "PRESIDENT", 	"female",	0, 	  "17-Nov-81", 	5000, 0, 10),
      (7844, "Turner", "Salesman", 	"trans",	7698, "8-Sep-81", 	1500, 0, 30),
      (7876, "ADAMS", "Clerk", 		"male",		7788, "23-May-87", 	1100, 0, 20)
    )).toDF("empno", "ename", "gender", "job", "mgr", "hiredate", "sal", "comm", "deptno")


case class Employee(empno: Int, ename: String, 
	gender: String, job: String, mgr: Int, hiredate: String,
  sal: Int, comm: Int, deptno: Int)

case class Department(id: Int, name: String)
val departments = sparkSession.createDataFrame(Seq(
	(10, "software"),
	(20, "hardware"),
	(30, "underwater basket weaving")
))

case class Employee(empno: Int, ename: String,
      job: String, mgr: Int, hiredate: String,
      sal: Int, comm: Int, deptno: Int)
