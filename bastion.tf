# --- 6. Bastion Host (Jump Server) ---

# Find the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Create an SSH key pair
resource "tls_private_key" "etl_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "etl_key_pair" {
  key_name   = "etl-etl-key"
  public_key = tls_private_key.etl_key.public_key_openssh
}

# Save the private key to your local machine
resource "local_file" "etl_private_key" {
  content         = tls_private_key.etl_key.private_key_pem
  filename        = "etl-etl-key.pem"
  file_permission = "0400" # Read-only for user
}

# Create the EC2 instance
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.etl_key_pair.key_name
  subnet_id     = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  tags = { Name = "etl-bastion-host" }
}