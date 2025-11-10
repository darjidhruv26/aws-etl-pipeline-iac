# --- Security Groups ---

# Security Group for Glue. Rules are defined separately below.
resource "aws_security_group" "glue_sg" {
  name        = "etl-glue-sg"
  description = "Security Group for ETL Glue"
  vpc_id      = aws_vpc.etl_vpc.id # Make sure this matches your VPC resource name
  tags        = { Name = "etl-glue-sg" }

  # Allow all traffic to itself (required for Glue)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1" # "-1" means "all"
    self      = true
  }

  # Allow responses from RDS
  ingress {
    description     = "Allow all traffic from RDS SG"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.rds_sg.id]
  }

  # Allow responses from Redshift
  ingress {
    description     = "Allow all traffic from Redshift SG"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.redshift_sg.id]
  }

  # Allow all outbound traffic (for POC)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for RDS. Rules are defined separately below.
resource "aws_security_group" "rds_sg" {
  name        = "etl-rds-sg"
  description = "Security Group for RDS"
  vpc_id      = aws_vpc.etl_vpc.id
  tags        = { Name = "etl-rds-sg" }
}

# Security Group for Redshift. Rules are defined separately below.
resource "aws_security_group" "redshift_sg" {
  name        = "etl-redshift-sg"
  description = "Security Group for Redshift"
  vpc_id      = aws_vpc.etl_vpc.id
  tags        = { Name = "etl-redshift-sg" }
}

# Security Group for the Bastion Host.
# This is the only group where inline rules are safe, as it doesn't depend on other groups.
resource "aws_security_group" "bastion_sg" {
  name        = "etl-bastion-sg"
  description = "Security Group for Bastion Host (SSH)"
  vpc_id      = aws_vpc.etl_vpc.id
  tags        = { Name = "etl-bastion-sg" }

  ingress {
    description = "Allow SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for VPC Interface Endpoints
resource "aws_security_group" "endpoint_sg" {
  name        = "etl-endpoint-sg"
  description = "Security Group for VPC Interface Endpoints"
  vpc_id      = aws_vpc.etl_vpc.id
  tags        = { Name = "etl-endpoint-sg" }

  # Allow traffic from Glue on required ports
  ingress {
    description     = "Allow HTTPS from Glue for AWS services"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.glue_sg.id]
  }

  # Allow traffic from Glue on the MySQL port for the RDS endpoint
  ingress {
    description     = "Allow MySQL from Glue for RDS endpoint"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.glue_sg.id]
  }
}

# --- Rules for RDS ---
resource "aws_security_group_rule" "rds_ingress_from_glue" {
  type                     = "ingress"
  description              = "Allow MySQL traffic from Glue"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.glue_sg.id
}

resource "aws_security_group_rule" "rds_ingress_from_bastion" {
  type                     = "ingress"
  description              = "Allow MySQL traffic from Bastion"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id
}

resource "aws_security_group_rule" "rds_egress_all" {
  type              = "egress"
  description       = "Allow all outbound traffic from RDS"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.rds_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# --- Rules for Redshift ---
resource "aws_security_group_rule" "redshift_ingress_from_glue" {
  type                     = "ingress"
  description              = "Allow Redshift traffic from Glue"
  from_port                = 5439
  to_port                  = 5439
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redshift_sg.id
  source_security_group_id = aws_security_group.glue_sg.id
}

resource "aws_security_group_rule" "redshift_ingress_from_bastion" {
  type                     = "ingress"
  description              = "Allow Redshift traffic from Bastion"
  from_port                = 5439
  to_port                  = 5439
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redshift_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id
}

resource "aws_security_group_rule" "redshift_egress_all" {
  type              = "egress"
  description       = "Allow all outbound traffic from Redshift"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.redshift_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}