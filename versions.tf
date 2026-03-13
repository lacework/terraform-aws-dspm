terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    lacework = {
      source  = "lacework/lacework"
      # TODO: set version to "~> 2.3" once the lacework provider is released
      version = "99.0.0"
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
