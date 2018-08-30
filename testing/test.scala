import org.apache.spark.sql.SparkSession
import spark.implicits._
import org.apache.spark.sql.functions
import org.apache.spark.sql.expressions.Window

val employees = spark.createDataFrame(Seq(
      (7369, "Smith", "Clerk",      "male",     7902, "17-Dec-80",  3000, 20, 10),
      (7499, "Alexa",       "Salesman",     "female",   7698, "20-Feb-81",  1600, 300, 30),
      (7521, "Ward",        "Salesman",     "male",     7698, "22-Feb-81",  1250, 500, 30),
      (7566, "Janice",      "Manager",      "female",   7839, "2-Apr-81",   2975, 0, 20),
      (7654, "Martin",      "Manager",      "male",     7698, "28-Sep-81",  1250, 1400, 30),
      (7698, "Becky",       "Manager",      "female",   7839, "1-May-81",   2850, 0, 30),
      (7782, "Clark",       "Manager",      "male",     7839, "9-Jun-81",   2450, 0, 10),
      (7788, "Stephanie",   "Analyst",      "female",   7566, "19-Apr-87",  3000, 0, 20),
      (7839, "Queen",       "President",    "female",   0,    "17-Nov-81",  5000, 0, 10),
      (7844, "Turner",      "Salesman",     "trans",    7698, "8-Sep-81",   1500, 0, 30),
      (7876, "Adams",       "Clerk",        "male",     7788, "23-May-87",  1100, 0, 20),
      (7876, "Ellen",       "Coder",        "female",     7708, "23-Sep-87",  1700, 1, 10),
      (7876, "Gokul",       "Hardware",     "male",     7908, "21-Sep-87",  2700, 1, 20),
      (234,  "Jon",               null,     "male",       23, "18-Aug-18",   234, 0, 10)
    )).toDF("empno", "ename", "job", "gender", "mgr", "hiredate", "sal", "comm", "deptno")


case class Employee(empno: Int, ename: String, job: String,
    gender: String, mgr: Int, hiredate: String,
    sal: Int, comm: Int, deptno: Int)

val departments = spark.createDataFrame(Seq(
    (10, "software"),
    (20, "hardware"),
    (30, "underwater basket weaving")
)).toDF("id", "name")

case class Department(id: Int, name: String)

// Cast to Dataset Example
employees.as[Employee].map(employee => employee.job)


// Example: Number of female employees in each department
employees.join(departments, departments("id") === employees("deptno"))
    .drop("id")
    .withColumnRenamed("name", "deptname")
    .filter('gender === "female")
    .groupBy("deptname")
    .count


val df = employees.join(departments, departments("id") === employees("deptno")).drop("id").withColumnRenamed("name", "deptname")

// Demonstrate first ignoreNulls=true
df.groupBy('job).agg(first(when('gender === "male", 'sal)))
df.groupBy('job).agg(first(when('gender === "male", 'sal), ignoreNulls=true))

// Window
val jobWindow = Window.partitionBy("job").orderBy('sal.desc)
df.withColumn("rank", row_number.over(jobWindow))

val deptWindow = Window.partitionBy("deptname").orderBy('sal.desc)
df.withColumn("mvp", row_number.over(deptWindow) === 1)


