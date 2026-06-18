# Configure the Lacework provider.
# See: https://registry.terraform.io/providers/lacework/lacework/latest/docs
provider "lacework" {
  profile = "default"
}

# AWS Organizations management account. The org-read role (account enumeration) and
# the member-role StackSet are created here, so this provider needs credentials for
# the management account — e.g. assume a role into it from your scanning-account
# credentials, as shown, or use a named profile.
provider "aws" {
  alias  = "management"
  region = "us-east-1"

  assume_role {
    role_arn = "arn:aws:iam::222222222222:role/OrganizationAccountAccessRole"
  }
}

# Scanner infrastructure, created in the scanning account using the default AWS
# provider (your ambient credentials / scanning-account profile).
module "lacework_dspm" {
  source = "../.."

  lacework_integration_name = "aws-dspm-org"
  scanning_account_id       = "111111111111" # account the scanner runs in
  regions                   = ["us-west-2"]

  # Org-level scope: scan the whole AWS organization (vs a single account).
  integration_level  = "org"
  management_account = "222222222222" # AWS Organizations management account ID

  # Optionally narrow the scope. Both accept AWS account IDs and/or OU/root IDs
  # (ou-…/r-…), expanded at scan time so new accounts in a monitored OU are picked
  # up automatically. The two are mutually exclusive.
  #
  # Scan everything EXCEPT these (e.g. exclude the management account):
  # excluded_accounts = ["222222222222"]
  #
  # Or scan ONLY these accounts/OUs:
  # included_accounts = ["ou-xxxx-xxxxxxxx"]

  tags = {
    ManagedBy = "terraform"
  }
}

# Management-account roles. Creates the org-read role (used to enumerate the org's
# accounts/OUs) and a SERVICE_MANAGED CloudFormation StackSet that deploys the
# read-only member role into every account in the target OUs — automatically covering
# new accounts added to those OUs later.
module "lacework_dspm_org_roles" {
  source = "../../modules/org-roles"
  providers = {
    aws = aws.management
  }

  member_role_cfn_template       = module.lacework_dspm.member_role_cfn_template
  scan_role_arns                 = values(module.lacework_dspm.dspm_scan_role_arns)
  target_organizational_unit_ids = ["ou-xxxx-xxxxxxxx"] # OUs to deploy the member role into
  stackset_instance_region       = "us-west-2"

  tags = {
    ManagedBy = "terraform"
  }
}
