output "org_read_role_arn" {
  description = "ARN of the org-enumeration role in the management account"
  value       = aws_iam_role.org_read.arn
}

output "member_role_stackset" {
  description = "Name of the StackSet that deploys the member read-role org-wide"
  value       = aws_cloudformation_stack_set.member_role.name
}
