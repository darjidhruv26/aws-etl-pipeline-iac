# Get 2 Availability Zones from the region
data "aws_availability_zones" "available" {
  state = "available"
}

# 1. Create the VPC
resource "aws_vpc" "etl_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "etl-vpc" }
}

# 2. Create Subnets
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.etl_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "etl-public-subnet-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.etl_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = { Name = "etl-public-subnet-b" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.etl_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = { Name = "etl-private-subnet-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.etl_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = { Name = "etl-private-subnet-b" }
}

# 3. Create Internet Gateway
resource "aws_internet_gateway" "etl_igw" {
  vpc_id = aws_vpc.etl_vpc.id
  tags = { Name = "etl-igw" }
}

# 4. Create NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.etl_igw]
}

resource "aws_nat_gateway" "etl_ngw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_a.id
  tags = { Name = "etl-nat-gw" }
  depends_on = [aws_internet_gateway.etl_igw]
}

# 5. Configure Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.etl_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.etl_igw.id
  }
  tags = { Name = "etl-public-rt" }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.etl_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.etl_ngw.id
  }
  tags = { Name = "etl-private-rt" }
}

# Associate Route Tables
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_rt.id
}

# 6. Create VPC Endpoints
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.etl_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    aws_route_table.private_rt.id,
    aws_route_table.public_rt.id # Also associate with public route table for consistency
  ]
  tags              = { Name = "etl-s3-endpoint" }
}

resource "aws_vpc_endpoint" "glue" {
  vpc_id            = aws_vpc.etl_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.glue"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids = [aws_security_group.endpoint_sg.id]
  private_dns_enabled = true
  tags              = { Name = "etl-glue-endpoint" }
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id            = aws_vpc.etl_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids = [aws_security_group.endpoint_sg.id]
  private_dns_enabled = true
  tags              = { Name = "etl-secrets-endpoint" }
}

resource "aws_vpc_endpoint" "sts" {
  vpc_id            = aws_vpc.etl_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids = [aws_security_group.endpoint_sg.id]
  private_dns_enabled = true
  tags              = { Name = "etl-sts-endpoint" }
}

resource "aws_vpc_endpoint" "rds" {
  vpc_id            = aws_vpc.etl_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.rds"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids = [aws_security_group.endpoint_sg.id]
  private_dns_enabled = true
  tags              = { Name = "etl-rds-endpoint" }
}