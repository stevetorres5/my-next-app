terraform {
  backend "s3" {
  }
}

data "aws_caller_identity" "account" {}

locals {
  region      = "us-west-2"
  application = "essaypop"
  env         = terraform.workspace
  account_id  = data.aws_caller_identity.account.account_id

  github_repo = "stevetorres5/my-next-app"
  ssm_path    = "${local.application}/${local.env}"
}

provider "aws" {
  region = local.region
}


import {
  to = aws_s3_bucket.terraform_state
  id = "${local.application}-${local.env}-tfstate"
}
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${local.application}-${local.env}-tfstate"
  lifecycle {
    # prevent_destroy = true
  }
}

import {
  to = aws_s3_bucket_versioning.versioning_config
  id = "${local.application}-${local.env}-tfstate"
}
resource "aws_s3_bucket_versioning" "versioning_config" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

import {
  to = aws_s3_bucket_server_side_encryption_configuration.sse_config
  id = "${local.application}-${local.env}-tfstate"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sse_config" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

import {
  to = aws_s3_bucket_public_access_block.terraform_state_public
  id = "${local.application}-${local.env}-tfstate"
}

resource "aws_s3_bucket_public_access_block" "terraform_state_public" {
  bucket                  = aws_s3_bucket.terraform_state.bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  depends_on              = [aws_s3_bucket.terraform_state]
}


import {
  to = aws_s3_bucket_policy.terraform_state_bucket_policy
  id = "${local.application}-${local.env}-tfstate"
}
resource "aws_s3_bucket_policy" "terraform_state_bucket_policy" {
  bucket = aws_s3_bucket.terraform_state.bucket

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "MustBeEncryptedInTransit",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource : [
          "${aws_s3_bucket.terraform_state.arn}",
          "${aws_s3_bucket.terraform_state.arn}/*"
        ],
        Condition = {
          Bool : {
            "aws:SecureTransport" : "false"
          }
        }
      },
      {
        Sid : "EnforceTLSv12orHigher",
        Effect : "Deny",
        Principal : {
          "AWS" : "*"
        },
        Action : "s3:*",
        Resource : [
          "${aws_s3_bucket.terraform_state.arn}",
          "${aws_s3_bucket.terraform_state.arn}/*"
        ],
        Condition : {
          NumericLessThan : {
            "s3:TlsVersion" : 1.2
          }
        }
      }
    ]
  })
}

