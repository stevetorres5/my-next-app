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

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${local.application}-${local.env}-tfstate"
  lifecycle {
    # prevent_destroy = true # TODO: Enable this line to prevent accidental deletion
  }
}

resource "aws_s3_bucket_versioning" "versioning_config" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sse_config" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_public" {
  bucket                  = aws_s3_bucket.terraform_state.bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  depends_on              = [aws_s3_bucket.terraform_state]
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

resource "aws_iam_openid_connect_provider" "openid_provider" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["2b18947a6a9fc7764fd8b5fb18a863b0c6dac24f"]
}

data "aws_iam_policy_document" "assume_role_trust_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type = "Federated"
      identifiers = [
        "arn:aws:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com"
      ]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "terraform_assumable_role" {
  name               = "${local.application}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_trust_policy.json
}

resource "aws_iam_role_policy_attachment" "amplify_admin_policy_attachment" {
  role       = aws_iam_role.terraform_assumable_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess-Amplify"
}

resource "aws_iam_role_policy" "terraform_assumable_role_inline_policy" {
  name = "essaypop-amplify_assumable_role_inline_policy"
  role = aws_iam_role.terraform_assumable_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${local.region}:${local.account_id}:parameter/${local.ssm_path}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.terraform_state.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.terraform_state.bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetRolePolicy"
        ]
        Resource = "*" # TODO: get guidance if this scope is too broad
      }
    ]
  })
}