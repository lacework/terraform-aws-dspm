# Integrate an AWS Organization with Lacework for DSPM

The following example integrates an entire AWS organization with Lacework for Data
Security Posture Management (DSPM) scanning. The scanner infrastructure is deployed
into a single scanning account, but S3 buckets are scanned across **every** account in
the organization: the scanner enumerates the org's accounts at scan time and assumes a
read-only role in each one. Because that member role is rolled out via a SERVICE_MANAGED
CloudFormation StackSet targeting your organizational units, accounts added to those OUs
in the future are picked up automatically.

> **Prerequisite:** An org-level deployment creates the org-read role and the member-role
> StackSet in your **AWS Organizations management account**. Configure a second AWS
> provider (aliased `management`) with credentials for that account — the example assumes
> a role into it. The identity running Terraform also needs StackSet/Organizations/IAM
> permissions there.

## Sample Code

```hcl
provider "lacework" {}

# Management account: org-read role + member-role StackSet are created here.
provider "aws" {
  alias  = "management"
  region = "us-east-1"

  assume_role {
    role_arn = "arn:aws:iam::222222222222:role/OrganizationAccountAccessRole"
  }
}

# Scanner infrastructure (deployed in the scanning account via the default provider).
module "lacework_dspm" {
  source  = "lacework/dspm/aws"
  version = "~> 0.2"

  lacework_integration_name = "aws-dspm-org"
  scanning_account_id       = "111111111111" # account the scanner runs in
  regions                   = ["us-west-2"]

  # Scan the whole organization.
  integration_level  = "org"
  management_account = "222222222222" # AWS Organizations management account ID
}

# Org-read role + member-role StackSet, created in the management account.
module "lacework_dspm_org_roles" {
  source  = "lacework/dspm/aws//modules/org-roles"
  version = "~> 0.2"

  providers = {
    aws = aws.management
  }

  member_role_cfn_template       = module.lacework_dspm.member_role_cfn_template
  scan_role_arns                 = values(module.lacework_dspm.dspm_scan_role_arns)
  target_organizational_unit_ids = ["ou-xxxx-xxxxxxxx"] # OUs to deploy the member role into
  stackset_instance_region       = "us-west-2"
}
```

## Narrowing the org scan

By default an org-level integration scans every account in the organization. You can
narrow this with **either** an include list **or** an exclude list (the two are mutually
exclusive). Both accept AWS account IDs and/or OU/root IDs (`ou-…`/`r-…`), which are
expanded to their member accounts at scan time.

Scan only specific accounts/OUs:
```hcl
module "lacework_dspm" {
  # ...
  integration_level  = "org"
  management_account = "222222222222"

  included_accounts = ["ou-xxxx-xxxxxxxx"]
}
```

Scan the whole org except specific accounts (e.g. the management account):
```hcl
module "lacework_dspm" {
  # ...
  integration_level  = "org"
  management_account = "222222222222"

  excluded_accounts = ["222222222222"]
}
```
