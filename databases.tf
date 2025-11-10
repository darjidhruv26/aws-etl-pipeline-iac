# --- 4. RDS (Source Database) ---

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "etl-rds-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  tags       = { Name = "etl-rds-subnet-group" }
}

resource "aws_db_instance" "etl_rds" {
  identifier             = "etl-rds-db"
  instance_class         = "db.m5.large"  # Use a general-purpose, fixed-performance instance
  engine                 = "mysql"
  allocated_storage      = 20
  availability_zone      = data.aws_availability_zones.available.names[1] # Pin to ap-south-1b
  username               = "etl_user" # Master username
  password               = random_password.rds_password.result # Use generated password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  tags                   = { Name = "etl-rds-db" }
}

# --- 5. Redshift (Destination Warehouse) ---

resource "aws_redshift_subnet_group" "redshift_subnet_group" {
  name       = "etl-redshift-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  tags       = { Name = "etl-redshift-subnet-group" }
}

resource "aws_redshift_cluster" "etl_redshift" {
  cluster_identifier        = "etl-redshift-cluster"
  node_type                 = "ra3.large" # Reverting to ra3.large as dc2.large is invalid in this region
  number_of_nodes           = 1
  database_name             = "dev"
  master_username           = "admin_user" # Master username
  master_password           = random_password.redshift_password.result # Use generated password
  cluster_subnet_group_name = aws_redshift_subnet_group.redshift_subnet_group.name
  vpc_security_group_ids    = [aws_security_group.redshift_sg.id]
  encrypted                 = true # Explicitly set to match the cluster's state
  availability_zone_relocation_enabled = true # Explicitly set to match the cluster's state
  publicly_accessible       = false
  skip_final_snapshot       = true
  iam_roles                 = [aws_iam_role.redshift_role.arn]
  tags                      = { Name = "etl-redshift-cluster" }
  depends_on                = [aws_iam_role_policy_attachment.redshift_custom]
}