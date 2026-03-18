# Integrate AWS with Lacework for DSPM in a Single Region

The following example integrates an AWS account with Lacework for Data Security Posture Management (DSPM) scanning deployed in a single AWS region. This is the simplest configuration — use this when all the S3 buckets you want to scan are in one region.

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
  regions                   = ["us-east-2"]
}
```

Optionally, you can configure scan frequency, maximum file size, and datastore filters:
```hcl
module "lacework_dspm" {
  source  = "lacework/dspm/aws"
  version = "~> 0.1"

  lacework_integration_name = "aws-dspm"
  scanning_account_id       = "000000000000"
  regions                   = ["us-east-2"]

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
  regions                   = ["us-east-2"]

  # Tags to propagate to any resources managed by the module.
  tags = {
    ManagedBy = "terraform"
  }
}
```
