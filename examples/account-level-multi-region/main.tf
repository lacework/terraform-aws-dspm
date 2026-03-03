provider "lacework" {
  profile = "default"
}

module "lacework_dspm" {
  source = "../.."

  lacework_integration_name = "aws-dspm-multi-region"
  scanning_account_id       = "971495677001"
  regions                   = ["us-west-2", "us-east-1"]
  global_region             = "us-east-1"

  tags = {
    ManagedBy = "terraform"
  }
}
