# --- 6. Glue Resources ---

resource "aws_s3_bucket" "staging_bucket" {
  # Bucket names must be globally unique.
  # Using random_id to ensure uniqueness for the POC.
  bucket = "etl-poc-staging-bucket-${random_id.bucket_suffix.hex}"
  tags   = { Name = "etl-staging-bucket" }
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}

resource "aws_s3_bucket_public_access_block" "staging" {
  bucket                  = aws_s3_bucket.staging_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_glue_catalog_database" "poc_catalog_db" {
  name = "etl_db_catalog"
}

# RDS Connection
resource "aws_glue_connection" "rds_conn" {
  name            = "rds-mysql-conn"
  connection_type = "JDBC"

  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:mysql://${aws_db_instance.etl_rds.endpoint}/poc_source_db"
    SECRET_ID           = aws_secretsmanager_secret.rds_creds.id # Use ID to reference the secret
  }

  physical_connection_requirements {
    subnet_id              = aws_subnet.private_b.id # Correctly set to private_b
    security_group_id_list = [aws_security_group.glue_sg.id]
    availability_zone      = data.aws_availability_zones.available.names[1] # Correctly set to ap-south-1b
  }
}

# Redshift Connection
resource "aws_glue_connection" "redshift_conn" {
  name            = "redshift-jdbc-connection"
  connection_type = "JDBC"

  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:redshift://${aws_redshift_cluster.etl_redshift.endpoint}/${aws_redshift_cluster.etl_redshift.database_name}"
    SECRET_ID           = aws_secretsmanager_secret.redshift_creds.id # Use ID to reference the secret
    "JDBC_ENFORCE_SSL"  = "true"
  }

  physical_connection_requirements {
    subnet_id              = aws_subnet.private_b.id # Change to private_b for consistency
    security_group_id_list = [aws_security_group.glue_sg.id]
    availability_zone      = data.aws_availability_zones.available.names[1] # Change to ap-south-1b
  }
}

# Glue Crawler
resource "aws_glue_crawler" "rds_crawler" {
  name          = "etl-rds-crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.poc_catalog_db.name

  jdbc_target {
    connection_name = aws_glue_connection.rds_conn.name
    path            = "poc_source_db/%"
  }

  # Ensure the connection is created first
  depends_on = [aws_glue_connection.rds_conn]
}

# Glue Job (placeholder, script must be created and uploaded)
resource "aws_glue_job" "etl_job" {
  name              = "poc-rds-to-redshift"
  role_arn          = aws_iam_role.glue_role.arn
  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 3 # Reduce workers to lower pressure on the source DB

  command {
    script_location = "s3://${aws_s3_bucket.staging_bucket.id}/scripts/etl_job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--TempDir"              = "s3://${aws_s3_bucket.staging_bucket.id}/temp/"
    "--job-bookmark-option"  = "job-bookmark-enable"
    "--CATALOG_DB"           = aws_glue_catalog_database.poc_catalog_db.name
    "--CATALOG_TABLE"        = "poc_source_db_customers"
    "--REDSHIFT_CONN"        = aws_glue_connection.redshift_conn.name
    "--redshiftTmpDir"       = "s3://${aws_s3_bucket.staging_bucket.id}/redshift-temp/" # Corrected parameter name
    "--REDSHIFT_DBTABLE"     = "public.customers"
    "--PREACTION_SQL"        = "CREATE TABLE IF NOT EXISTS public.customers (id INTEGER, first_name VARCHAR(50), last_name VARCHAR(50), email VARCHAR(100), registration_date DATE);"
  }

  # The job depends on the crawler having been created.
  depends_on = [aws_glue_crawler.rds_crawler]
}

# Upload the Glue script (you must create this file)
resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.staging_bucket.id
  key    = "scripts/etl_job.py"
  source = "etl_job.py" # This file must exist in your project folder
  etag   = filemd5("etl_job.py")
}