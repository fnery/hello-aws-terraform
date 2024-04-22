# Provider configuration
provider "aws" {
    profile = "default"
    region = "us-east-1"
}

# Retrieve default VPC configuration from AWS
data "aws_vpc" "default" {
  default = true
}

# Security group to allow SSH traffic from any IP address
resource "aws_security_group" "allow_ssh" {
  name        = "allow-ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow SSH"
  }
}

# Private RSA key for use in securing SSH access
resource "tls_private_key" "rsa_4096" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# AWS key pair using the public key generated from the private RSA key
resource "aws_key_pair" "terraform_key" {
  key_name   = "terraform-key"
  public_key = tls_private_key.rsa_4096.public_key_openssh
}

# Save private RSA key locally for SSH access
resource "local_file" "private_key" {
  content  = tls_private_key.rsa_4096.private_key_pem
  filename = "${path.cwd}/terraform-key.pem"
  file_permission = "0400"
}

# Deploy EC2 instance
resource "aws_instance" "app_server" {
    ami = "ami-04e5276ebb8451442"
    instance_type = "t2.micro"
    key_name = aws_key_pair.terraform_key.key_name
    security_groups = [aws_security_group.allow_ssh.name]
    tags = {
        Name = "app-server"
    }
}

# SNS topic for billing alerts
resource "aws_sns_topic" "billing_alarm" {
  name = "billing-alarm-topic"
}

# Subscribe email address to the SNS topic for billing alerts; requires confirmation
resource "aws_sns_topic_subscription" "billing_alarm_email" {
  topic_arn = aws_sns_topic.billing_alarm.arn
  protocol  = "email"
  endpoint  = var.email
}

# CloudWatch metric alarm to notify via SNS when estimated charges exceed a defined threshold
resource "aws_cloudwatch_metric_alarm" "billing_alarm" {
  alarm_name                = "billing-alarm"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  metric_name               = "EstimatedCharges"
  namespace                 = "AWS/Billing"
  period                    = 21600
  statistic                 = "Maximum"
  threshold                 = 5
  alarm_description         = "Alert if estimated charges exceed $5.00"
  insufficient_data_actions = []
  actions_enabled           = true
  alarm_actions             = [aws_sns_topic.billing_alarm.arn]
  dimensions = {
      Currency = "USD"
  }
}
