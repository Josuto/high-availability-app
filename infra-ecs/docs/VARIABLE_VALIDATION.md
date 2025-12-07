# Variable Validation Rules

This document describes all input validation rules implemented across Terraform modules to catch configuration errors early and provide helpful guidance to users.

## Overview

Variable validation ensures that only valid values can be passed to modules, catching errors at `terraform plan` time rather than during `terraform apply`. Each validation includes a clear error message to guide users toward correct values.

## ALB Module

**File:** `infra-ecs/modules/alb/vars.tf`

| Variable | Validation Rule | Error Message |
|----------|----------------|---------------|
| `container_port` | Must be 1-65535 | "Container port must be between 1 and 65535." |
| `deregistration_delay` | Must be 0-3600 seconds | "Deregistration delay must be between 0 and 3600 seconds." |
| `environment` | Must be "dev" or "prod" | "The environment must be either 'dev' or 'prod'." |

### Examples

```hcl
# Valid
container_port = 3000
deregistration_delay = 30

# Invalid - will fail validation
container_port = 99999  # Error: Container port must be between 1 and 65535
deregistration_delay = 5000  # Error: Deregistration delay must be between 0 and 3600 seconds
```

## ECS Service Module

**File:** `infra-ecs/modules/ecs_service/vars.tf`

| Variable | Validation Rule | Error Message |
|----------|----------------|---------------|
| `container_port` | Must be 1-65535 | "Container port must be between 1 and 65535." |
| `cpu_limit` | Must be one of: 256, 512, 1024, 2048, 4096, 8192, 16384 | "CPU limit must be one of: 256, 512, 1024, 2048, 4096, 8192, 16384." |
| `memory_limit` | Must be 128-122880 MB | "Memory limit must be between 128 MB and 122880 MB (120 GB)." |
| `ecs_task_desired_count` | Must be >= 0 | "ECS task desired count must be a non-negative integer." |
| `deployment_minimum_healthy_percent` | Must be 0-100 | "Deployment minimum healthy percent must be between 0 and 100." |
| `deployment_maximum_percent` | Must be 100-200 | "Deployment maximum percent must be between 100 and 200." |
| `environment` | Must be "dev" or "prod" | "The environment must be either 'dev' or 'prod'." |

### AWS ECS CPU/Memory Valid Combinations

The `cpu_limit` values correspond to AWS Fargate/ECS task CPU units:
- **256** (0.25 vCPU): Memory 512-2048 MB
- **512** (0.5 vCPU): Memory 1024-4096 MB
- **1024** (1 vCPU): Memory 2048-8192 MB
- **2048** (2 vCPU): Memory 4096-16384 MB
- **4096** (4 vCPU): Memory 8192-30720 MB
- **8192** (8 vCPU): Memory 16384-61440 MB
- **16384** (16 vCPU): Memory 32768-122880 MB

### Examples

```hcl
# Valid
cpu_limit = 1024
memory_limit = 2048
ecs_task_desired_count = 2
deployment_minimum_healthy_percent = 50
deployment_maximum_percent = 200

# Invalid - will fail validation
cpu_limit = 300  # Error: CPU limit must be one of: 256, 512, 1024...
memory_limit = 50  # Error: Memory limit must be between 128 MB and 122880 MB
deployment_minimum_healthy_percent = 150  # Error: Must be between 0 and 100
```

## ECS Cluster Module

**File:** `infra-ecs/modules/ecs_cluster/vars.tf`

| Variable | Validation Rule | Error Message |
|----------|----------------|---------------|
| `ecs_instance_type` | Must match EC2 instance type format | "Instance type must be a valid EC2 instance type format (e.g., t2.micro, t3.small, m5.large)." |
| `instance_min_size` | Must be 0-1000 | "Instance min size must be between 0 and 1000." |
| `instance_max_size` | Must be 1-1000 AND >= min_size | "Instance max size must be between 1 and 1000." / "Instance max size must be greater than or equal to instance min size." |
| `environment` | Must be "dev" or "prod" | "The environment must be either 'dev' or 'prod'." |

### EC2 Instance Type Format

The validation uses a regex pattern to ensure instance types follow AWS naming conventions:
- **Pattern:** `[family][generation][additional][.][size]`
- **Examples:** `t2.micro`, `t3.small`, `m5.large`, `c5n.xlarge`, `r5a.2xlarge`
- **Valid sizes:** nano, micro, small, medium, large, xlarge, 2xlarge, 4xlarge, etc.

### Examples

```hcl
# Valid
ecs_instance_type = "t3.small"
instance_min_size = 1
instance_max_size = 4

# Invalid - will fail validation
ecs_instance_type = "invalid-type"  # Error: Must be valid EC2 instance type format
instance_min_size = 5
instance_max_size = 2  # Error: Must be >= instance_min_size
```

## ECR Module

**File:** `infra-ecs/modules/ecr/vars.tf`

| Variable | Validation Rule | Error Message |
|----------|----------------|---------------|
| `image_retention_max_count` | All values must be 1-1000 | "Image retention max count must be between 1 and 1000 for each environment." |
| `environment` | Must be "dev" or "prod" | "The environment must be either 'dev' or 'prod'." |

### Examples

```hcl
# Valid
image_retention_max_count = {
  dev  = 3
  prod = 10
}

# Invalid - will fail validation
image_retention_max_count = {
  dev  = 0     # Error: Must be between 1 and 1000
  prod = 2000  # Error: Must be between 1 and 1000
}
```

## Validation Patterns

### Port Numbers
```hcl
validation {
  condition     = var.port > 0 && var.port <= 65535
  error_message = "Port must be between 1 and 65535."
}
```

### Positive Integers with Range
```hcl
validation {
  condition     = var.count >= 1 && var.count <= 1000
  error_message = "Count must be between 1 and 1000."
}
```

### Percentage Values
```hcl
validation {
  condition     = var.percent >= 0 && var.percent <= 100
  error_message = "Percentage must be between 0 and 100."
}
```

### Enum Values
```hcl
validation {
  condition     = contains(["value1", "value2"], var.option)
  error_message = "Option must be either 'value1' or 'value2'."
}
```

### Format Validation (Regex)
```hcl
validation {
  condition     = can(regex("^pattern$", var.string))
  error_message = "String must match the expected format."
}
```

### Map Value Validation
```hcl
validation {
  condition = alltrue([
    for v in values(var.map) : v > 0 && v <= 100
  ])
  error_message = "All map values must be between 1 and 100."
}
```

### Cross-Variable Validation
```hcl
variable "max_value" {
  validation {
    condition     = var.max_value >= var.min_value
    error_message = "Max value must be greater than or equal to min value."
  }
}
```

## Testing Validation Rules

### Test with Valid Values
```bash
terraform validate
# Should output: Success! The configuration is valid.
```

### Test with Invalid Values
Create a `test.tfvars` with invalid values:
```hcl
container_port = 99999
```

Run:
```bash
terraform plan -var-file=test.tfvars
```

Expected output:
```
Error: Invalid value for variable

Container port must be between 1 and 65535.
```

## Best Practices

1. **Clear Error Messages**: Include the valid range or format in the error message
2. **Early Validation**: Fail fast at plan time rather than apply time
3. **Reasonable Limits**: Use AWS service limits as validation boundaries
4. **Multiple Validations**: A variable can have multiple validation blocks
5. **Document Constraints**: Document validation rules in module READMEs

## Adding New Validations

When adding validation to a new variable:

1. **Identify Constraints**: What are the AWS service limits or logical constraints?
2. **Write Condition**: Use Terraform functions (contains, can, regex, etc.)
3. **Helpful Error Message**: Guide the user to the correct value
4. **Test**: Try both valid and invalid values
5. **Document**: Add to this file and module README

### Example Template

```hcl
variable "new_variable" {
  description = "Description of the variable"
  type        = number
  default     = 100

  validation {
    condition     = var.new_variable >= 1 && var.new_variable <= 1000
    error_message = "New variable must be between 1 and 1000."
  }
}
```

## References

- [Terraform Variable Validation](https://developer.hashicorp.com/terraform/language/values/variables#custom-validation-rules)
- [AWS ECS Task Definition Parameters](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html)
- [AWS EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [AWS ALB Target Group Attributes](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)
- [AWS Auto Scaling Group Limits](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-quotas.html)

## Maintenance

**Last Updated:** 2025-11-28

When AWS service limits change, update the validation rules accordingly. Review this document during:
- AWS service limit changes
- New module creation
- Module updates
- Quarterly security reviews
