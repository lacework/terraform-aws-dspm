<!-- BEGIN_TF_DOCS -->
# Terraform AWS DSPM Module

Terraform module for integrating AWS Data Security Posture Management (DSPM) with Lacework.

This module creates the necessary AWS resources for DSPM scanning, including:
- Lacework cloud account integration
- ECS Cluster on AWS Fargate for scanner tasks
- EventBridge Rule for scheduled scanning
- S3 bucket for scan results
- Secret Manager secret for Lacework credentials
- DynamoDB table for scanner cache
- VPC and networking configuration
- Required IAM roles and policies

## Usage Examples
- [Account-level Single Region](./examples/account-level-single-region/)
- [Account-level Multi Region](./examples/account-level-multi-region/)

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.3 |
| aws | ~> 6.0 |
| lacework | ~> 2.2 |
| time | ~> 0.9 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 6.0 |
| lacework | ~> 2.2 |
| random | n/a |
| time | ~> 0.9 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| additional\_environment\_variables | Optional list of additional environment variables passed to the scanner task. | <pre>list(object({<br>    name  = string<br>    value = string<br>  }))</pre> | `[]` | no |
| additional\_trusted\_role\_arns | Additional IAM role ARNs allowed to assume the DSPM scan role (e.g. for local debugging). | `list(string)` | `[]` | no |
| ecs\_task\_cpu | CPU units for ECS task (256, 512, 1024, 2048, 4096) | `number` | `1024` | no |
| ecs\_task\_memory | Memory for ECS task in MB (512, 1024, 2048, 4096, 8192, etc.) | `number` | `2048` | no |
| global\_region | Region for global resources (S3 bucket, etc). Defaults to first region in var.regions. | `string` | `""` | no |
| lacework\_aws\_account\_id | The Lacework AWS account that the IAM role will grant access. | `string` | `"434813966438"` | no |
| lacework\_domain | Lacework domain for API server | `string` | `"lacework.net"` | no |
| lacework\_hostname | Hostname for the Lacework account (e.g., my-tenant.lacework.net). If not provided, will use the URL associated with the default Lacework CLI profile. | `string` | `""` | no |
| lacework\_integration\_name | Name of the DSPM integration in FortiCNAPP | `string` | `"aws-dspm"` | no |
| regions | List of AWS regions where DSPM scanners are deployed. | `list(string)` | n/a | yes |
| resource\_prefix | Prefix for resource names (also used for S3 bucket name with account ID appended for uniqueness) | `string` | `"forticnapp-dspm"` | no |
| scanner\_image | Docker image for the DSPM scanner | `string` | `"lacework/dspm-scanner:latest"` | no |
| scanning\_account\_id | AWS Account ID where the DSPM scanner will be deployed | `string` | n/a | yes |
| tags | Tags to apply to all resources | `map(string)` | <pre>{<br>  "ManagedBy": "terraform"<br>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| dspm\_scan\_role\_arns | Map of region to IAM role ARN that the scanner assumes for S3 access |
| dynamodb\_table\_names | Map of region to DynamoDB table name |
| ecs\_cluster\_arns | Map of region to ECS cluster ARN |
| ecs\_cluster\_names | Map of region to ECS cluster name |
| ecs\_task\_definition\_arns | Map of region to ECS task definition ARN |
| ecs\_task\_role\_arns | Map of region to ECS task role ARN |
| eventbridge\_rule\_names | Map of region to EventBridge rule name |
| eventbridge\_schedule | EventBridge schedule expression |
| lacework\_hostname | Lacework hostname for the integration (e.g., my-tenant.lacework.net) |
| lacework\_integration\_id | ID of the FortiCNAPP DSPM integration |
| lacework\_integration\_name | Name of the Lacework DSPM integration |
| output\_bucket\_arn | ARN of the S3 output bucket |
| output\_bucket\_name | Name of the S3 output bucket (for scan results) |
| scanning\_account\_id | AWS Account ID being scanned |
| secret\_arns | Map of region to DSPM scan secret ARN |
| security\_group\_ids | Map of region to security group ID for ECS tasks |
| subnet\_ids | Map of region to list of public subnet IDs |
| suffix | Suffix used to add uniqueness to resource names |
| vpc\_ids | Map of region to VPC ID |
<!-- END_TF_DOCS -->