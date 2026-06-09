# This submodule creates the org-level resources that live in the AWS Organizations
# MANAGEMENT account: the org-enumeration role the scanner assumes for discovery,
# and the SERVICE_MANAGED StackSet that rolls the per-account member read-role out
# across the org. Call it with the management-account provider:
#
#   module "dspm_org_roles" {
#     source    = "lacework-dev/dspm/aws//modules/org-roles"  # adjust to your source
#     providers = { aws = aws.management }
#     member_role_cfn_template       = module.dspm.member_role_cfn_template
#     scan_role_arns                 = values(module.dspm.dspm_scan_role_arns)
#     target_organizational_unit_ids = ["ou-xxxx-xxxxxxxx"]
#     stackset_instance_region       = "us-west-2"
#   }

variable "member_role_cfn_template" {
  type        = string
  description = "CloudFormation template (JSON) for the per-account member read-role, from the DSPM module's member_role_cfn_template output."
}

variable "target_organizational_unit_ids" {
  type        = list(string)
  description = "Organizational unit IDs (or the org root ID) to deploy the member read-role StackSet into. Accounts later added to these OUs are covered automatically."
  validation {
    condition     = length(var.target_organizational_unit_ids) > 0
    error_message = "At least one organizational unit (or root) ID is required."
  }
}

variable "scan_role_arns" {
  type        = list(string)
  description = "DSPM scan role ARNs (from the module's dspm_scan_role_arns output) permitted to assume the org-read role."
}

variable "org_read_role_name" {
  type        = string
  default     = "forticnapp-dspm-org-read-role"
  description = "Name of the org-enumeration role created in the management account."
}

variable "stackset_name" {
  type        = string
  default     = "forticnapp-dspm-member-role"
  description = "Name of the CloudFormation StackSet that deploys the member read-role."
}

variable "stackset_instance_region" {
  type        = string
  description = "Region for the StackSet stack instances. IAM is global, so the role is created once per account regardless."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to the org-read role."
}
