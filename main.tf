terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  tags = {
    Project     = "Test"
    Environment = "Dev"
  }
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ssm_profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_iam_role" "ssm_role" {
  name = "ssm_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore", "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"]
}

module "ec2_instance_1" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name                   = var.instance_1_name
  ami                    = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = var.vpc_security_group_ids_instance_1_name
  subnet_id              = var.subnet_id_instance_1_name
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.id
  user_data              = <<EOT
    #!/bin/bash
    aws s3 cp s3://${aws_s3_bucket.bucket_script.id}/script.sh /home/ssm-user/script.sh
    chmod +x /home/ssm-user/script.sh    
    EOT
  root_block_device = [
    {
      encrypted   = true
      volume_type = "gp2"
      volume_size = var.ec2_volume_size
    }
  ]

  tags = local.tags
}

module "ec2_instance_2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name                   = var.instance_2_name
  ami                    = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = var.vpc_security_group_ids_instance_2_name
  subnet_id              = var.subnet_id_instance_2_name
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.id
  root_block_device = [
    {
      encrypted   = true
      volume_type = "gp2"
      volume_size = var.ec2_volume_size
    }
  ]

  tags = local.tags
}

resource "aws_s3_bucket" "bucket_script" {
  bucket_prefix = "bucket-script-"
  acl           = "private"
  force_destroy = true
}

resource "aws_s3_bucket_object" "script" {
  bucket = aws_s3_bucket.bucket_script.id
  key    = "script.sh"
  source = var.script_source
  etag   = filemd5(var.script_source)
}


