# Configure the Lacework provider.
# See: https://registry.terraform.io/providers/lacework/lacework/latest/docs
provider "lacework" {
  profile = "default"
}

module "lacework_dspm" {
  source = "../.."

  lacework_integration_name = "aws-dspm-multi-region"
  scanning_account_id       = "971495677001"
  regions                   = ["us-west-2", "us-east-1"]
  global_region             = "us-east-1"

  # Uncomment to set the scan frequency (valid values: 24, 72, 168, 720 hours)
  # scan_frequency_hours = 168

  # Uncomment to set the maximum file size to scan in MB (valid values: 1-50)
  # max_file_size_mb = 5

  # Uncomment to control which datastores to scan (filter_mode: INCLUDE, EXCLUDE, or ALL)
  # datastore_filters = {
  #   filter_mode     = "INCLUDE"
  #   datastore_names = ["my-datastore"]
  # }

  tags = {
    ManagedBy = "terraform"
  }
}
