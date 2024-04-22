# Output public DNS name of the deployed EC2 instance
output "public_dns" {
  value = aws_instance.app_server.public_dns
  description = "The public DNS name of the instance"
}
