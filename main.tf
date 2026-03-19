locals {
  suffix = random_id.suffix.hex
  prefix = var.resource_prefix

  /* global_region is the region that we use for global resources.
  If the global_region variable is not set, we use the first region in the regions list variable.
  */
  global_region = coalesce(var.global_region, var.regions[0])

  /* region_keys is the data structure that we loop through to create per-region resources.
  keys are regions, values are sanitized strings for resource names
  e.g. { "us-west-2" = "uswest2", "us-east-1" = "useast1", ... }
  */
  region_keys             = { for r in var.regions : r => replace(r, "-", "") }
  storage_bucket_arn      = aws_s3_bucket.storage.arn
  storage_bucket_id       = aws_s3_bucket.storage.id
  lacework_hostname       = length(var.lacework_hostname) > 0 ? var.lacework_hostname : data.lacework_user_profile.current.url
  external_id             = lacework_external_id.aws_iam_external_id.v2
  cross_account_role_name = "${local.prefix}-cross-account-role-${local.suffix}"

  /* subnet_pairs is an intermediate data structure that is used to create the subnet_map
  e.g. [ { "region" = "us-west-2", "region_key" = "uswest2", "index" = 0, "map_key" = "us-west-2-0" }, { "region" = "us-west-2", "region_key" = "uswest2", "index" = 1, "map_key" = "us-west-2-1" }, ... ]
  */
  subnet_pairs = flatten([
    for region, key in local.region_keys : [
      for i in [0, 1] : {
        region     = region
        region_key = key
        index      = i
        map_key    = "${region}-${i}"
      }
    ]
  ])
  /* We loop through subnet_map using `for_each` to create 2 subnets per region.
  We need to create this map ahead of time because Terraform doesn't allow us to use `for_each` and `count` on the same resource
  e.g. { 
    "us-west-2-0" = { "region" = "us-west-2", "region_key" = "uswest2", "index" = 0, "map_key" = "us-west-2-0" },
    "us-west-2-1" = { "region" = "us-west-2", "region_key" = "uswest2", "index" = 1, "map_key" = "us-west-2-1" }, 
    ... 
  }
  */
  subnet_map = { for s in local.subnet_pairs : s.map_key => s }
}

resource "random_id" "suffix" {
  byte_length = 2
}

data "lacework_user_profile" "current" {}

# ------------------------------------------------------------
# Lacework DSPM Integration
# ------------------------------------------------------------

resource "lacework_external_id" "aws_iam_external_id" {
  csp        = "aws"
  account_id = data.aws_caller_identity.current.account_id
}

resource "lacework_integration_aws_dspm" "lacework_cloud_account" {
  name               = var.lacework_integration_name
  account_id         = var.scanning_account_id
  storage_bucket_arn = local.storage_bucket_arn
  regions            = var.regions
  credentials {
    external_id = local.external_id
    role_arn    = aws_iam_role.dspm_cross_account_role.arn
  }
  scan_frequency_hours = var.scan_frequency_hours
  max_file_size_mb     = var.max_file_size_mb

  dynamic "datastore_filters" {
    for_each = var.datastore_filters != null ? [var.datastore_filters] : []
    content {
      filter_mode     = datastore_filters.value.filter_mode
      datastore_names = length(datastore_filters.value.datastore_names) > 0 ? datastore_filters.value.datastore_names : null
    }
  }
}

# ------------------------------------------------------------
# Secrets Manager (per-region)
# ------------------------------------------------------------

resource "aws_secretsmanager_secret" "dspm_lacework_credentials" {
  for_each = local.region_keys
  region   = each.key

  name = "${local.prefix}-secret-${each.value}-${local.suffix}"
  tags = var.tags

  # Force immediate deletion on destroy (no recovery window)
  # This prevents "secret already scheduled for deletion" errors on re-apply
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "dspm_lacework_credentials_version" {
  for_each  = local.region_keys
  region    = each.key
  secret_id = aws_secretsmanager_secret.dspm_lacework_credentials[each.key].id
  secret_string = jsonencode({
    hostName = local.lacework_hostname
    token    = lacework_integration_aws_dspm.lacework_cloud_account.server_token
  })
}

# ------------------------------------------------------------
# Storage
# ------------------------------------------------------------

# S3 Bucket for Scan Results/Output (global)
resource "aws_s3_bucket" "storage" {
  bucket        = "${local.prefix}-storage-${local.suffix}"
  force_destroy = true

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}-storage-${local.suffix}"
    }
  )
}

# Retention Policies
resource "aws_s3_bucket_lifecycle_configuration" "results_expiration" {
  bucket = aws_s3_bucket.storage.id

  rule {
    id     = "delete-results-after-7-days"
    status = "Enabled"
    
    filter {
    prefix = "results/"
    }
    expiration {
      days = 7
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "scratch_expiration" {
  bucket = aws_s3_bucket.storage.id

  rule {
    id     = "delete-scratch-after-1-day"
    status = "Enabled"
    
    filter {
    prefix = "scratch/"
    }
    expiration {
      days = 1
    }
  }
}

# S3 Output Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "storage" {
  bucket = local.storage_bucket_id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Output Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "storage" {
  bucket = local.storage_bucket_id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for Scanner Cache (per-region)
resource "aws_dynamodb_table" "scanner_cache" {
  for_each     = local.region_keys
  region       = each.key
  name         = "${local.prefix}-scanner-cache-${each.value}-${local.suffix}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "StoreName"
  range_key    = "ObjectName"

  attribute {
    name = "StoreName"
    type = "S"
  }

  attribute {
    name = "ObjectName"
    type = "S"
  }

  ttl {
    attribute_name = "ExpiresAt"
    enabled        = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}-scanner-cache-${each.value}-${local.suffix}"
    }
  )
}

# ------------------------------------------------------------
# IAM (Cross Account Role for Lacework Platform) — global
# ------------------------------------------------------------

data "aws_iam_policy_document" "dspm_cross_account_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.lacework_aws_account_id}:role/lacework-platform"]
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [local.external_id]
    }
  }
}

data "aws_iam_policy_document" "cross_account_inline_policy_bucket" {
  statement {
    sid    = "ListAndTagBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketTagging",
      "s3:PutBucketTagging"
    ]
    resources = [local.storage_bucket_arn]
  }

  statement {
    sid    = "PutGetDeleteObjectsInBucket"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:PutObject",
      "s3:GetObject"
    ]
    resources = ["${local.storage_bucket_arn}/*"]
  }
}

resource "aws_iam_role" "dspm_cross_account_role" {
  name                 = local.cross_account_role_name
  max_session_duration = 3600
  path                 = "/"
  assume_role_policy   = data.aws_iam_policy_document.dspm_cross_account_policy.json

  tags = var.tags
}

resource "aws_iam_policy" "agentless_s3_write_policy" {
  name = "${local.prefix}-s3-write-policy-${local.suffix}"

  policy = data.aws_iam_policy_document.cross_account_inline_policy_bucket.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "agentless_s3_write_policy_attachment" {
  role       = aws_iam_role.dspm_cross_account_role.name
  policy_arn = aws_iam_policy.agentless_s3_write_policy.arn
}

# ------------------------------------------------------------
# Networking (per-region)
# ------------------------------------------------------------

# Data source to get available availability zones (per-region)
data "aws_availability_zones" "available" {
  for_each = local.region_keys
  region   = each.key
  state    = "available"
}

# VPC for ECS
resource "aws_vpc" "main" {
  for_each = local.region_keys
  region   = each.key

  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}-vpc-${each.value}-${local.suffix}"
    }
  )
}

# Public Subnets (per-region)
# We have 2 subnets, each in different availability zones for redundancy
resource "aws_subnet" "public" {
  for_each = local.subnet_map
  region   = each.value.region

  vpc_id                  = aws_vpc.main[each.value.region].id
  cidr_block              = "10.0.${(each.value.index + 1) * 32}.0/20"
  availability_zone       = data.aws_availability_zones.available[each.value.region].names[each.value.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}-subnet-${each.value.region_key}-${each.value.index + 1}-${local.suffix}"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  for_each = local.region_keys
  region   = each.key

  vpc_id = aws_vpc.main[each.key].id

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}-gateway-${each.value}-${local.suffix}"
    }
  )
}

# Route Table
resource "aws_route_table" "public" {
  for_each = local.region_keys
  region   = each.key

  vpc_id = aws_vpc.main[each.key].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[each.key].id
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}-route-${each.value}-${local.suffix}"
    }
  )
}

# Route Table Association
resource "aws_route_table_association" "public" {
  for_each = local.subnet_map
  region   = each.value.region

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[each.value.region].id
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  for_each = local.region_keys
  region   = each.key

  name        = "${local.prefix}-ecs-tasks-sg-${each.value}-${local.suffix}"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main[each.key].id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}-ecs-tasks-sg-${each.value}-${local.suffix}"
    }
  )
}

# ------------------------------------------------------------
# Compute (per-region)
# ------------------------------------------------------------

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  for_each = local.region_keys
  region   = each.key

  name = "${local.prefix}-cluster-${each.value}-${local.suffix}"

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}-cluster-${each.value}-${local.suffix}"
    }
  )
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs" {
  for_each = local.region_keys
  region   = each.key

  name              = "/ecs/${local.prefix}-scanner-${each.value}-${local.suffix}"
  retention_in_days = 7

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}-ecs-logs-${each.value}-${local.suffix}"
    }
  )
}

# IAM Role for ECS Task Execution (global — one role shared across regions)
resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.prefix}-task-execution-role-${local.suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}-task-execution-role-${local.suffix}"
    }
  )
}

# IAM Policy for ECS Task Execution (ECR and CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task (Application permissions) (per-region)
resource "aws_iam_role" "ecs_task" {
  for_each = local.region_keys

  name = "${local.prefix}-task-role-${each.value}-${local.suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}-task-role-${each.value}-${local.suffix}"
    }
  )
}

# IAM Policy for ECS Task (per-region)
# Note: The ECS task role only has AssumeRole permission.
# All S3 scanning permissions (including access to input/output buckets) are provided
# through the dspm_scan IAM role that the scanner assumes at runtime.
resource "aws_iam_role_policy" "ecs_task" {
  for_each = local.region_keys

  name = "${local.prefix}-task-policy-${each.value}-${local.suffix}"
  role = aws_iam_role.ecs_task[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = aws_iam_role.dspm_scan[each.key].arn
      }
    ]
  })
}

# Wait for ECS task role to propagate before referencing it as a principal.
# IAM validates principals in trust policies at creation time and will reject
# the policy if the referenced role hasn't propagated yet.
resource "time_sleep" "wait_for_ecs_task_role_propagation" {
  for_each = local.region_keys

  depends_on = [
    aws_iam_role.ecs_task,
  ]

  create_duration = "10s"
}

# IAM Role for DSPM Scanner (per-region, assumed by ECS task at runtime)
resource "aws_iam_role" "dspm_scan" {
  for_each = local.region_keys

  depends_on = [
    time_sleep.wait_for_ecs_task_role_propagation,
  ]

  name = "${local.prefix}-scan-role-${each.value}-${local.suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ecs_task[each.key].arn
        }
      }
      ],
      length(var.additional_trusted_role_arns) > 0 ? [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            AWS = var.additional_trusted_role_arns
          }
        }
    ] : [])
  })

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}-scan-role-${each.value}-${local.suffix}"
    }
  )
}

# IAM Policy for DSPM Scanner (per-region)
resource "aws_iam_role_policy" "dspm_scan" {
  for_each = local.region_keys

  name = "${local.prefix}-scan-policy-${each.value}-${local.suffix}"
  role = aws_iam_role.dspm_scan[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketPolicyStatus",
          "s3:GetBucketAcl",
          "s3:ListBucket",
          "s3:GetObject",
        ]
        Resource = "*"
      },
      # DynamoDB Cache Access (regional)
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:BatchGetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.scanner_cache[each.key].arn
      },
      # Write scan results to the output bucket (global)
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          local.storage_bucket_arn,
          "${local.storage_bucket_arn}/*"
        ]
      },
      # Launch auxiliary scanning tasks from the main scanning task (regional)
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:StartTask",
          "ecs:StopTask",
          "ecs:ListTasks",
          "ecs:Describe*",
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "ecs:cluster" = aws_ecs_cluster.main[each.key].arn
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecretVersionIds",
          "secretsmanager:GetSecretValue",
          "secretsmanager:GetResourcePolicy"
        ]
        Resource = [
          aws_secretsmanager_secret.dspm_lacework_credentials[each.key].arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole",
        ]
        Resource = [
          aws_ecs_task_definition.scanner[each.key].execution_role_arn,
          aws_ecs_task_definition.scanner[each.key].task_role_arn
        ]
      }
    ]
  })
}

# ECS Task Definition (per-region)
resource "aws_ecs_task_definition" "scanner" {
  for_each = local.region_keys
  region   = each.key

  family                   = "${local.prefix}-scanner-${each.value}-${local.suffix}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task[each.key].arn

  container_definitions = jsonencode([
    {
      name  = "scanner"
      image = var.scanner_image

      environment = concat([
        {
          name  = "CLOUD_PROVIDER"
          value = "AWS"
        },
        {
          name  = "REGION"
          value = each.key
        },
        {
          name  = "OUTPUT_BUCKET"
          value = local.storage_bucket_id
        },
        {
          name  = "OUTPUT_BUCKET_REGION"
          value = local.global_region
        },
        {
          name  = "CACHE_TABLE_NAME"
          value = aws_dynamodb_table.scanner_cache[each.key].name
        },
        {
          name  = "SCANNING_ACCOUNT_ID"
          value = data.aws_caller_identity.current.account_id
        },
        {
          name  = "DSPM_SCAN_ROLE_ARN"
          value = aws_iam_role.dspm_scan[each.key].arn
        },
        {
          name  = "CLUSTER_ARN"
          value = aws_ecs_cluster.main[each.key].arn
        },
        {
          name  = "TASK_DEFINITION_FAMILY"
          value = "${local.prefix}-scanner-${each.value}-${local.suffix}"
        },
        {
          name  = "SECURITY_GROUP_ID"
          value = aws_security_group.ecs_tasks[each.key].id
        },
        {
          name  = "SUBNET_IDS"
          value = join(",", [for s in local.subnet_pairs : aws_subnet.public[s.map_key].id if s.region == each.key])
        },
        {
          name  = "SECRET_ARN"
          value = aws_secretsmanager_secret.dspm_lacework_credentials[each.key].arn
        }
      ], var.additional_environment_variables)

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs[each.key].name
          "awslogs-region"        = each.key
          "awslogs-stream-prefix" = "scanner"
        }
      }
    }
  ])

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}-task-definition-${each.value}-${local.suffix}"
    }
  )
}

# ------------------------------------------------------------
# Scheduling (per-region)
# ------------------------------------------------------------

# IAM Role for EventBridge (per-region)
resource "aws_iam_role" "eventbridge" {
  for_each = local.region_keys

  name = "${local.prefix}-eventbridge-role-${each.value}-${local.suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}-eventbridge-role-${each.value}-${local.suffix}"
    }
  )
}

# AWS managed policy for EventBridge to run ECS tasks (per-region)
resource "aws_iam_role_policy_attachment" "eventbridge" {
  for_each = local.region_keys

  role       = aws_iam_role.eventbridge[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
}

# Wait for IAM policy to propagate before creating EventBridge rule.
# IAM is eventually consistent — the role policy attachment may not be
# available for use by EventBridge for up to 60s after creation.
resource "time_sleep" "wait_for_iam_propagation" {
  for_each = local.region_keys

  depends_on = [
    aws_iam_role_policy_attachment.eventbridge,
  ]

  create_duration = "60s"
}

# EventBridge Rule for hourly schedule (per-region)
resource "aws_cloudwatch_event_rule" "hourly_scan" {
  for_each = local.region_keys
  region   = each.key

  depends_on = [
    time_sleep.wait_for_iam_propagation,
  ]

  name                = "${local.prefix}-hourly-scan-${each.value}-${local.suffix}"
  description         = "Trigger DSPM scanner task every hour"
  schedule_expression = "rate(1 hour)"

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}-hourly-scan-rule-${each.value}-${local.suffix}"
    }
  )
}

# EventBridge Target for ECS Task (per-region)
resource "aws_cloudwatch_event_target" "ecs_task" {
  for_each = local.region_keys
  region   = each.key

  rule      = aws_cloudwatch_event_rule.hourly_scan[each.key].name
  target_id = "ecs-scanner-task"
  arn       = aws_ecs_cluster.main[each.key].arn
  role_arn  = aws_iam_role.eventbridge[each.key].arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.scanner[each.key].arn
    launch_type         = "FARGATE"

    network_configuration {
      subnets          = [for s in local.subnet_pairs : aws_subnet.public[s.map_key].id if s.region == each.key]
      security_groups  = [aws_security_group.ecs_tasks[each.key].id]
      assign_public_ip = true
    }
  }
}
