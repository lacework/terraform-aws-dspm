# Integrate AWS with Lacework for DSPM Across Multiple Regions

The following example integrates an AWS account with Lacework for Data Security Posture Management (DSPM) scanning deployed across multiple AWS regions. A `global_region` is specified for shared resources (like the S3 output bucket), while scanners are deployed to each region in the `regions` list.

## Sample Code

```hcl
provider "aws" {}

provider "lacework" {}

module "lacework_dspm" {
  source  = "lacework/dspm/aws"
  version = "~> 0.1"

  # Name of the Lacework cloud account integration.
  lacework_integration_name = "aws-dspm"
  # AWS Account ID where the DSPM scanner will be deployed.
  scanning_account_id       = "000000000000"
  # Regions to deploy scanners to.
  regions                   = ["us-west-2", "us-east-1"]
  # Region to deploy shared resources to.
  global_region             = "us-east-1"
}
```

Optionally, you can configure scan frequency, maximum file size, and datastore filters:
```hcl
module "lacework_dspm" {
  source  = "lacework/dspm/aws"
  version = "~> 0.1"

  lacework_integration_name = "aws-dspm"
  scanning_account_id       = "000000000000"
  regions                   = ["us-west-2", "us-east-1"]
  global_region             = "us-east-1"

  # How often the DSPM scanner runs (valid values: 24, 72, 168, 720 hours).
  scan_frequency_hours = 168

  # Maximum file size to scan in MB (valid values: 1-50).
  max_file_size_mb = 5

  # Control which datastores to scan (filter_mode: INCLUDE, EXCLUDE, or ALL).
  datastore_filters = {
    filter_mode     = "INCLUDE"
    datastore_names = ["my-datastore"]
  }
}
```

A `tags` block can be used to add custom tags to the resources managed by the module. For example:
```hcl
module "lacework_dspm" {
  source  = "lacework/dspm/aws"
  version = "~> 0.1"

  lacework_integration_name = "aws-dspm"
  scanning_account_id       = "000000000000"
  regions                   = ["us-west-2", "us-east-1"]
  global_region             = "us-east-1"

  # Tags to propagate to any resources managed by the module.
  tags = {
    ManagedBy = "terraform"
  }
}
```
