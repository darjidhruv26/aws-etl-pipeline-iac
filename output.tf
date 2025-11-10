output "bastion_public_ip" {
  description = "Public IP of the Bastion host for SSH."
  value       = aws_instance.bastion.public_ip
}

output "rds_endpoint" {
  description = "Endpoint of the RDS MySQL database."
  value       = aws_db_instance.etl_rds.endpoint
}

output "redshift_endpoint" {
  description = "Endpoint of the Redshift cluster."
  value       = aws_redshift_cluster.etl_redshift.endpoint
}

output "private_key_filename" {
  description = "The name of the private key file saved to your directory."
  value       = local_file.etl_private_key.filename
}