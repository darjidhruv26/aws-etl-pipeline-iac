variable "aws_region" {
  description = "The AWS region to deploy to."
  type        = string
  default     = "ap-south-1"
}

variable "my_ip" {
  description = "Your local IP address to allow SSH access to the Bastion Host."
  type        = string
  sensitive   = true
}