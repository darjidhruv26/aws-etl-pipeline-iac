# --- 3. Secrets Manager ---

# Generate a random password for the RDS database
resource "random_password" "rds_password" {
  length           = 16
  special          = true
  min_numeric      = 1
  min_upper        = 1
  min_lower        = 1
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "rds_creds" {
  name                    = "etl/rds-creds-${random_id.bucket_suffix.hex}"
  kms_key_id              = aws_kms_key.secrets_key.arn # Encrypt with our KMS key
  recovery_window_in_days = 0                           # For immediate deletion in dev
  tags                    = { Name = "etl-rds-creds" }
}

resource "aws_secretsmanager_secret_version" "rds_creds_version" {
  secret_id     = aws_secretsmanager_secret.rds_creds.id
  secret_string = jsonencode({
    username = "etl_user"
    password = random_password.rds_password.result
  })
}

# Generate a random password for the Redshift cluster
resource "random_password" "redshift_password" {
  length           = 16
  special          = true
  min_numeric      = 1
  min_upper        = 1
  min_lower        = 1
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "redshift_creds" {
  name                    = "etl/redshift-creds-${random_id.bucket_suffix.hex}"
  kms_key_id              = aws_kms_key.secrets_key.arn # Encrypt with our KMS key
  recovery_window_in_days = 0                           # For immediate deletion in dev
  tags                    = { Name = "etl-redshift-creds" }
}

# Store the initial random password in Secrets Manager for Redshift
resource "aws_secretsmanager_secret_version" "redshift_creds_version" {
  secret_id = aws_secretsmanager_secret.redshift_creds.id
  secret_string = jsonencode({
    username = "admin_user"
    password = random_password.redshift_password.result
  })
}