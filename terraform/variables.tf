variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-west-2"
}

variable "github_owner" {
  description = "GitHub owner/org"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}
