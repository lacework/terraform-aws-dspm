provider "lacework" {
  profile = "default"
}

module "lacework_dspm" {
  source = "../.."

  lacework_integration_name = "aws-dspm"
  scanning_account_id       = "971495677001"
  regions                   = ["us-east-2"]

  tags = {
    ManagedBy = "terraform"
  }
}
