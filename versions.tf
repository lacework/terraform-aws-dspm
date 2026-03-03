terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    lacework = {
      source  = "lacework/lacework"
      version = "~> 2.2"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "aws" {
  region = local.global_region
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}
