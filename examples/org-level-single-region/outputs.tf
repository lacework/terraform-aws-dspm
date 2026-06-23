output "output_bucket_name" {
  description = "Name of the S3 output bucket (for scan results)"
  value       = module.lacework_dspm.output_bucket_name
}

output "scanning_account_id" {
  description = "AWS Account ID the scanner runs in"
  value       = module.lacework_dspm.scanning_account_id
}

output "lacework_integration_id" {
  description = "ID of the FortiCNAPP DSPM integration"
  value       = module.lacework_dspm.lacework_integration_id
}

output "lacework_hostname" {
  description = "Lacework hostname for the integration (e.g., my-tenant.lacework.net)"
  value       = module.lacework_dspm.lacework_hostname
}

output "dspm_scan_role_arns" {
  description = "Map of region to IAM role ARN that the scanner assumes for S3 access"
  value       = module.lacework_dspm.dspm_scan_role_arns
}

# Org-level resources (created by the org-roles submodule in the management account)
output "org_read_role_arn" {
  description = "ARN of the org-enumeration role in the management account"
  value       = module.lacework_dspm_org_roles.org_read_role_arn
}

output "member_role_stackset" {
  description = "Name of the StackSet that deploys the read-only member role org-wide"
  value       = module.lacework_dspm_org_roles.member_role_stackset
}
