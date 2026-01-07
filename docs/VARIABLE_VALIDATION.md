# Variable Validation Rules

This document describes all input validation rules implemented across Terraform modules to catch configuration errors early and provide helpful guidance to users.

All examples are based on the ECS-based solution included at `infra-ecs/`. However, the variable validation principles and practices explained at this document apply the EKS-based approach at `infra-eks/` as well.

## Overview

Variable validation ensures that only valid values can be passed to modules, catching errors at `terraform plan` time rather than during `terraform apply`. Each validation includes a clear error message to guide users toward correct values.

## ALB Module (ECS Example)

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
- [AWS ALB Target Group Attributes](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)

## Maintenance

**Last Updated:** 2026-01-08

When AWS service limits change, update the validation rules accordingly. Review this document during:
- AWS service limit changes
- New module creation
- Module updates
- Quarterly security reviews
