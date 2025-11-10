import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

# Get job arguments
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',               # Standard argument
    'CATALOG_DB',
    'CATALOG_TABLE',
    'REDSHIFT_CONN',
    'redshiftTmpDir',         # Corrected parameter name for the temporary directory
    'REDSHIFT_DBTABLE',
    'PREACTION_SQL'
])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# 1. Extract (Read from Glue Catalog)
print("Reading data from Glue Catalog...")
datasource0 = glueContext.create_dynamic_frame.from_catalog(
    database=args['CATALOG_DB'],
    table_name=args['CATALOG_TABLE'],
    transformation_ctx="datasource0"
)

# 3. Load (Write to Redshift)
print("Writing data to Redshift...")
datasink4 = glueContext.write_dynamic_frame.from_options(
    frame=datasource0,
    connection_type="redshift",
    connection_options={
        "redshiftTmpDir": args['redshiftTmpDir'],
        "useConnectionProperties": "true",
        "connectionName": args['REDSHIFT_CONN'],
        "dbtable": args['REDSHIFT_DBTABLE'],
        "preactions": args['PREACTION_SQL'] # Use the preaction SQL command
    },
    transformation_ctx="datasink4"
)

print("Data written to Redshift successfully.")
job.commit()