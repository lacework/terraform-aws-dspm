output "output_bucket_name" {
  description = "Name of the S3 output bucket (for scan results)"
  value       = local.storage_bucket_id
}

output "output_bucket_arn" {
  description = "ARN of the S3 output bucket"
  value       = local.storage_bucket_arn
}

output "ecs_cluster_names" {
  description = "Map of region to ECS cluster name"
  value       = { for r, cluster in aws_ecs_cluster.main : r => cluster.name }
}

output "ecs_cluster_arns" {
  description = "Map of region to ECS cluster ARN"
  value       = { for r, cluster in aws_ecs_cluster.main : r => cluster.arn }
}

output "ecs_task_definition_arns" {
  description = "Map of region to ECS task definition ARN"
  value       = { for r, td in aws_ecs_task_definition.scanner : r => td.arn }
}

output "vpc_ids" {
  description = "Map of region to VPC ID"
  value       = { for r, vpc in aws_vpc.main : r => vpc.id }
}

output "eventbridge_rule_names" {
  description = "Map of region to EventBridge rule name"
  value       = { for r, rule in aws_cloudwatch_event_rule.hourly_scan : r => rule.name }
}

output "eventbridge_schedule" {
  description = "EventBridge schedule expression"
  value       = "rate(1 hour)"
}

output "dspm_scan_role_arns" {
  description = "Map of region to IAM role ARN that the scanner assumes for S3 access"
  value       = { for r, role in aws_iam_role.dspm_scan : r => role.arn }
}

output "ecs_task_role_arns" {
  description = "Map of region to ECS task role ARN"
  value       = { for r, role in aws_iam_role.ecs_task : r => role.arn }
}

output "scanning_account_id" {
  description = "AWS Account ID being scanned"
  value       = data.aws_caller_identity.current.account_id
}

output "security_group_ids" {
  description = "Map of region to security group ID for ECS tasks"
  value       = { for r, sg in aws_security_group.ecs_tasks : r => sg.id }
}

output "subnet_ids" {
  description = "Map of region to list of public subnet IDs"
  value = {
    for r in var.regions : r => [
      for s in local.subnet_pairs : aws_subnet.public[s.map_key].id if s.region == r
    ]
  }
}

output "dynamodb_table_names" {
  description = "Map of region to DynamoDB table name"
  value       = { for r, table in aws_dynamodb_table.scanner_cache : r => table.name }
}

output "lacework_integration_id" {
  description = "ID of the FortiCNAPP DSPM integration"
  value       = lacework_integration_aws_dspm.lacework_cloud_account.id
}

output "secret_arns" {
  description = "Map of region to DSPM scan secret ARN"
  value       = { for r, secret in aws_secretsmanager_secret.dspm_lacework_credentials : r => secret.arn }
}

output "lacework_integration_name" {
  description = "Name of the Lacework DSPM integration"
  value       = var.lacework_integration_name
}

output "lacework_hostname" {
  description = "Lacework hostname for the integration (e.g., my-tenant.lacework.net)"
  value       = local.lacework_hostname
}

output "suffix" {
  description = "Suffix used to add uniqueness to resource names"
  value       = random_id.suffix.hex
}
