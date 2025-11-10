# --- 0. KMS Key for Secrets ---
resource "aws_kms_key" "secrets_key" {
  description             = "KMS key for encrypting secrets for the ETL process"
  deletion_window_in_days = 7
  tags                    = { Name = "etl-secrets-kms-key" }
}

# Allow AWS services (like Glue) to use the key
resource "aws_iam_policy" "kms_usage_policy" {
  name = "etl-kms-usage-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["kms:Decrypt"], # Glue needs to decrypt the secret
        Resource = aws_kms_key.secrets_key.arn
      }
    ]
  })
}

# Get the current AWS account ID for ARN construction
data "aws_caller_identity" "current" {}

# --- 1. AWS Glue Service Role ---
resource "aws_iam_role" "glue_role" {
  name = "etl-glue-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "glue.amazonaws.com" }
    }]
  })
  tags = { Name = "etl-glue-role" }
}

# Attach the AWS managed policy for basic Glue functionality (contains CloudWatch Logs permissions etc.)
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Create a custom, least-privilege policy for the Glue Role
resource "aws_iam_policy" "glue_custom_policy" {
  name = "etl-glue-custom-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        # Grant access to the staging bucket for scripts, temp files, etc.
        Resource = [
          aws_s3_bucket.staging_bucket.arn,
          "${aws_s3_bucket.staging_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = "secretsmanager:GetSecretValue",
        Resource = [
          aws_secretsmanager_secret.rds_creds.arn,
          aws_secretsmanager_secret.redshift_creds.arn
        ]
      },
      {
        Effect = "Allow",
        Action = "kms:Decrypt",
        Resource = aws_kms_key.secrets_key.arn
      }
    ]
  })
}

# Attach the custom policy to the Glue role
resource "aws_iam_role_policy_attachment" "glue_custom" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_custom_policy.arn
}

# 2. Amazon Redshift IAM Role
# Redshift needs this role to access S3 for COPY commands
resource "aws_iam_role" "redshift_role" {
  name = "etl-redshift-s3-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "redshift.amazonaws.com" }
    }]
  })
  tags = { Name = "etl-redshift-role" }
}

# Create a custom, least-privilege policy for the Redshift Role
resource "aws_iam_policy" "redshift_s3_policy" {
  name = "etl-redshift-s3-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        # Grant access to the staging bucket for Redshift COPY command
        Resource = [
          aws_s3_bucket.staging_bucket.arn,
          "${aws_s3_bucket.staging_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Attach the custom policy to the Redshift role
resource "aws_iam_role_policy_attachment" "redshift_custom" {
  role       = aws_iam_role.redshift_role.name
  policy_arn = aws_iam_policy.redshift_s3_policy.arn
}