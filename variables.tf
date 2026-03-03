variable "regions" {
  type        = list(string)
  description = "List of AWS regions where DSPM scanners are deployed."
  validation {
    condition     = length(var.regions) > 0
    error_message = "At least one region must be specified."
  }
}

variable "global_region" {
  type        = string
  default     = ""
  description = "Region for global resources (S3 bucket, etc). Defaults to first region in var.regions."
}

variable "resource_prefix" {
  description = "Prefix for resource names (also used for S3 bucket name with account ID appended for uniqueness)"
  type        = string
  default     = "forticnapp-dspm"
}

variable "ecs_task_cpu" {
  description = "CPU units for ECS task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 1024
}

variable "ecs_task_memory" {
  description = "Memory for ECS task in MB (512, 1024, 2048, 4096, 8192, etc.)"
  type        = number
  default     = 2048
}

variable "scanner_image" {
  description = "Docker image for the DSPM scanner"
  type        = string
  default     = "lacework/dspm-scanner:latest"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "terraform"
  }
}

variable "lacework_domain" {
  description = "Lacework domain for API server"
  type        = string
  default     = "lacework.net"
}

variable "lacework_hostname" {
  description = "Hostname for the Lacework account (e.g., my-tenant.lacework.net). If not provided, will use the URL associated with the default Lacework CLI profile."
  type        = string
  default     = ""
}

variable "lacework_integration_name" {
  description = "Name of the DSPM integration in FortiCNAPP"
  type        = string
  default     = "aws-dspm"
}

variable "additional_environment_variables" {
  type = list(object({
    name  = string
    value = string
  }))
  default     = []
  description = "Optional list of additional environment variables passed to the scanner task."
}

variable "scanning_account_id" {
  description = "AWS Account ID where the DSPM scanner will be deployed"
  type        = string
  validation {
    condition     = length(var.scanning_account_id) > 0
    error_message = "scanning_account_id must be a non-empty string."
  }
}

variable "additional_trusted_role_arns" {
  type        = list(string)
  default     = []
  description = "Additional IAM role ARNs allowed to assume the DSPM scan role (e.g., for testing outside of the scheduled ECS task)."
}

variable "lacework_aws_account_id" {
  type        = string
  default     = "434813966438"
  description = "The Lacework AWS account that the IAM role will grant access."
}
