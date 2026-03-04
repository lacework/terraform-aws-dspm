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
