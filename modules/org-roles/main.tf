# All resources here are created in the management account (the caller maps the
# management-account provider to this module's default `aws` provider).

# Org-enumeration role — the scanner assumes this to list the org's accounts/OUs
# for ORG-level discovery / OU expansion.
resource "aws_iam_role" "org_read" {
  name = var.org_read_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = var.scan_role_arns }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "org_read" {
  name = "org-read"
  role = aws_iam_role.org_read.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "organizations:ListAccounts",
        "organizations:ListAccountsForParent",
        "organizations:ListOrganizationalUnitsForParent",
        "organizations:ListRoots",
        "organizations:DescribeOrganization",
        "organizations:DescribeAccount",
      ]
      Resource = "*"
    }]
  })
}

# Member read-role, deployed org-wide via a SERVICE_MANAGED StackSet. auto_deployment
# covers accounts added to the target OUs later. The role definition (trust + perms)
# is the DSPM module's canonical member_role_cfn_template.
resource "aws_cloudformation_stack_set" "member_role" {
  name             = var.stackset_name
  description      = "FortiCNAPP DSPM member read-only S3 roles (org-wide)"
  permission_model = "SERVICE_MANAGED"
  capabilities     = ["CAPABILITY_NAMED_IAM"]

  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }

  template_body = var.member_role_cfn_template

  # Prevent an update loop on the service-managed admin role ARN.
  # https://github.com/hashicorp/terraform-provider-aws/issues/23464
  lifecycle {
    ignore_changes = [administration_role_arn]
  }
}

resource "aws_cloudformation_stack_set_instance" "member_role" {
  deployment_targets {
    organizational_unit_ids = var.target_organizational_unit_ids
  }
  stack_set_instance_region = var.stackset_instance_region
  stack_set_name            = aws_cloudformation_stack_set.member_role.name
}
