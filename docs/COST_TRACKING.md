# Cost Tracking and Tagging Strategy

**Last Updated:** 2025-12-03
**Status:** Implemented

## Overview

This document describes the comprehensive tagging strategy implemented across all AWS resources to enable accurate cost allocation, tracking, and FinOps practices. All resources are tagged using a **dual-layer approach**: provider-level default tags and module-level specific tags.

## Tagging Architecture

### Layer 1: Provider Default Tags

Applied automatically to **all resources** via AWS provider `default_tags` configuration:

```hcl
provider "aws" {
  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = var.environment       # dev or prod
      Project     = var.project_name      # Project identifier
      Owner       = "Platform Team"       # Team responsible
      CostCenter  = "Engineering"         # For chargeback
    }
  }
}
```

**Location:** `infra/deployment/*/provider.tf`

**Benefits:**
- ✅ Guaranteed consistency across all resources
- ✅ No manual tagging required per resource
- ✅ Reduces tag drift and human error
- ✅ Centralized tag management

### Layer 2: Module-Specific Tags

Applied via `locals.tf` in each module for enhanced tracking:

```hcl
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Module      = "module_name"         # Which module created this
    CreatedDate = timestamp()           # When resource was created
  }
}
```

**Location:** `infra/modules/*/locals.tf`

**Benefits:**
- ✅ Module-level cost tracking
- ✅ Resource lifecycle tracking via timestamp
- ✅ Easy identification of resource origin
- ✅ Audit trail for compliance

## Standard Tags

| Tag | Example Value | Purpose | Required |
|-----|---------------|---------|----------|
| **Project** | `terraform-course-dummy-nestjs-app` | Identifies project/application | ✅ Yes |
| **Environment** | `dev` or `prod` | Deployment environment | ✅ Yes |
| **ManagedBy** | `Terraform` | Infrastructure-as-Code tool | ✅ Yes |
| **Module** | `alb`, `ecs_cluster`, `ssl` | Terraform module that created resource | ✅ Yes |
| **Owner** | `Platform Team` | Team responsible for resource | ✅ Yes |
| **CostCenter** | `Engineering` | For chargeback and budget allocation | ✅ Yes |
| **CreatedDate** | `2025-12-03T10:30:00Z` | Resource creation timestamp | ✅ Yes |
| **Name** | `ecs-ec2-container` | Human-readable resource name | ⚠️ Optional |

## Tag Inheritance Model

```
┌─────────────────────────────────────────┐
│   Provider Default Tags (Layer 1)      │
│   ┌─────────────────────────────────┐   │
│   │ ManagedBy, Environment, Project │   │
│   │ Owner, CostCenter               │   │
│   └─────────────────────────────────┘   │
│              ↓ Applied to ALL resources │
└─────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│   Module Tags (Layer 2)                 │
│   ┌─────────────────────────────────┐   │
│   │ Module, CreatedDate             │   │
│   │ + Resource-specific tags        │   │
│   └─────────────────────────────────┘   │
│              ↓ Extends default tags     │
└─────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│   Final Resource Tags                   │
│   ┌─────────────────────────────────┐   │
│   │ All 7 standard tags             │   │
│   └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

**Note:** Module tags **supplement** (not replace) provider default tags. AWS merges both sets, with module tags taking precedence if there's overlap.

## Implementation by Module

### Module Structure

Each module contains a `locals.tf` file with:

```hcl
# Example: infra/modules/alb/locals.tf
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Module      = "alb"
    CreatedDate = timestamp()
  }
}
```

### Module List

| Module | Module Tag Value | Resources Tagged |
|--------|------------------|------------------|
| `alb` | `alb` | ALB, Target Groups, Security Groups, Listeners |
| `ecs_cluster` | `ecs_cluster` | ECS Cluster, ASG, Launch Template, IAM Roles, SG |
| `ecs_service` | `ecs_service` | ECS Service, Task Definition, CloudWatch Logs, IAM |
| `ecr` | `ecr` | ECR Repository |
| `ssl` | `ssl` | ACM Certificate, Route53 Validation Records |
| `hosted_zone` | `hosted_zone` | Route53 Hosted Zone |
| `routing` | N/A | Route53 A Records (not taggable) |
| `alb_rule` | `alb_rule` | ALB Listener Rules (when enabled) |

### Special Cases

#### EC2 Instances (ECS Cluster)

EC2 instances launched by the Auto Scaling Group require an additional `Name` tag:

```hcl
locals {
  instance_tags = merge(
    local.common_tags,
    {
      Name = "ecs-ec2-container"
    }
  )
}
```

#### Resources Without Tag Support

Some AWS resources don't support tags:
- Route53 A/CNAME records
- ALB Listener Rules (listeners only)
- Security Group Rules (SG only)

## Cost Tracking in AWS

### AWS Cost Explorer Filters

Use these tags to filter costs in AWS Cost Explorer:

1. **By Environment:**
   - Tag Key: `Environment`
   - Tag Value: `dev` or `prod`
   - **Use Case:** Compare dev vs prod infrastructure costs

2. **By Project:**
   - Tag Key: `Project`
   - Tag Value: `terraform-course-dummy-nestjs-app`
   - **Use Case:** Track total project spend

3. **By Module:**
   - Tag Key: `Module`
   - Tag Value: `alb`, `ecs_cluster`, `ecs_service`, etc.
   - **Use Case:** Identify most expensive infrastructure components

4. **By Cost Center:**
   - Tag Key: `CostCenter`
   - Tag Value: `Engineering`
   - **Use Case:** Chargeback to department budgets

5. **By Owner:**
   - Tag Key: `Owner`
   - Tag Value: `Platform Team`
   - **Use Case:** Team accountability for costs

### Cost Allocation Report Setup

1. **Enable Cost Allocation Tags in AWS Billing Console:**
   ```
   AWS Console → Billing → Cost Allocation Tags → User-Defined Tags
   ```

2. **Activate these tags:**
   - ✅ Environment
   - ✅ Project
   - ✅ Module
   - ✅ Owner
   - ✅ CostCenter
   - ✅ ManagedBy

3. **Wait 24 hours** for tags to appear in Cost Explorer

### Sample Cost Queries

**Query 1: Monthly Cost by Environment**
```
Group By: Environment
Time Period: Last 12 months
Filters: Project = terraform-course-dummy-nestjs-app
```

**Query 2: Current Month Cost by Module**
```
Group By: Module
Time Period: This month
Filters: Environment = prod
```

**Query 3: Cost Trend by Owner**
```
Group By: Owner
Time Period: Last 3 months
Chart Type: Line
```

## FinOps Best Practices

### 1. Regular Cost Reviews

**Weekly:**
- Review anomalies via AWS Cost Anomaly Detection
- Check for untagged resources

**Monthly:**
- Cost by module analysis
- Environment cost comparison (dev should be < prod)
- Identify optimization opportunities

### 2. Tagging Compliance

**Automated Checks:**
```bash
# Run Terraform validation
cd infra && ./run-tests.sh

# Check for missing tags (AWS CLI)
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=ManagedBy,Values=Terraform \
  --resource-type-filters ec2 ecs elasticloadbalancing \
  --query 'ResourceTagMappingList[?length(Tags) < `7`]'
```

**Manual Audits:**
- Quarterly review of all resources in AWS Console
- Verify tag consistency across regions
- Update tags for new resource types

### 3. Cost Optimization

**Module-Level Analysis:**
```
1. Query: Cost by Module (last 30 days)
2. Identify highest cost modules
3. Investigate:
   - ecs_cluster: Right-size EC2 instances
   - alb: Enable access logs analysis
   - ecr: Review image retention policies
```

## Timestamp Behavior

The `CreatedDate` tag uses Terraform's `timestamp()` function:

**Important Notes:**
- ⚠️ Timestamp updates on **every Terraform apply**
- ✅ First apply sets the creation date
- ⚠️ Subsequent applies will update the timestamp
- 💡 For immutable timestamps, use data sources or external scripts

**Why we accept this trade-off:**
- Provides approximation of creation date
- More important: enables resource age estimation
- Can be combined with CloudTrail for exact creation time if needed

## Lifecycle Management

### Adding New Tags

1. Update provider `default_tags` in all `provider.tf` files
2. Update module `locals.tf` files if module-specific
3. Run `terraform plan` to preview changes
4. Apply to dev environment first
5. Validate in AWS Console
6. Apply to prod environment

### Deprecating Tags

1. Remove from provider `default_tags`
2. Remove from module `locals.tf` files
3. Run `terraform plan` (tags won't be destroyed, just not managed)
4. Optional: Manually remove old tags via AWS CLI

### Renaming Tags

⚠️ **Caution:** Tag renames cause tag deletion + recreation

1. Add new tag first (both layers)
2. Apply to all environments
3. Wait 30 days (for cost reports to reflect new tag)
4. Remove old tag
5. Apply to all environments

## Compliance and Governance

### Tag Enforcement

**Pre-commit Validation:**
```bash
# Runs automatically via pre-commit hooks
terraform validate
tflint
```

**CI/CD Validation:**
- GitHub Actions `test-terraform-modules` job validates all modules
- Ensures `locals.tf` exists in each module
- Checks for tag consistency

### Audit Trail

All tagging changes are tracked via:
1. **Git History:** `infra/modules/*/locals.tf` and `infra/deployment/*/provider.tf`
2. **Terraform State:** State files record all tag values
3. **CloudTrail:** AWS API calls for tag updates

## Examples

### Example 1: ALB Load Balancer Tags

```hcl
# Provider adds (Layer 1):
{
  ManagedBy   = "Terraform"
  Environment = "prod"
  Project     = "terraform-course-dummy-nestjs-app"
  Owner       = "Platform Team"
  CostCenter  = "Engineering"
}

# Module adds (Layer 2):
{
  Module      = "alb"
  CreatedDate = "2025-12-03T14:25:00Z"
}

# Final tags in AWS:
{
  ManagedBy   = "Terraform"
  Environment = "prod"
  Project     = "terraform-course-dummy-nestjs-app"
  Owner       = "Platform Team"
  CostCenter  = "Engineering"
  Module      = "alb"
  CreatedDate = "2025-12-03T14:25:00Z"
}
```

### Example 2: ECS EC2 Instance Tags

```hcl
# Provider adds (Layer 1):
{
  ManagedBy   = "Terraform"
  Environment = "prod"
  Project     = "terraform-course-dummy-nestjs-app"
  Owner       = "Platform Team"
  CostCenter  = "Engineering"
}

# Module adds (Layer 2):
{
  Module      = "ecs_cluster"
  CreatedDate = "2025-12-03T14:30:00Z"
  Name        = "ecs-ec2-container"  # Instance-specific
}

# Final tags in AWS:
{
  ManagedBy   = "Terraform"
  Environment = "prod"
  Project     = "terraform-course-dummy-nestjs-app"
  Owner       = "Platform Team"
  CostCenter  = "Engineering"
  Module      = "ecs_cluster"
  CreatedDate = "2025-12-03T14:30:00Z"
  Name        = "ecs-ec2-container"
}
```

## Troubleshooting

### Issue: Tags not appearing in Cost Explorer

**Solution:**
1. Verify tags are activated in AWS Billing → Cost Allocation Tags
2. Wait 24 hours after activation
3. Confirm resources have tags via AWS Console
4. Check if resource type supports cost allocation tags

### Issue: Tag inconsistency across resources

**Solution:**
1. Run `terraform plan` to see drift
2. Apply Terraform to reconcile
3. For resources created outside Terraform, manually tag or import

### Issue: CreatedDate keeps changing

**Expected Behavior:** `timestamp()` updates on each apply

**If this is problematic:**
1. Replace `timestamp()` with hardcoded date
2. Use `terraform import` metadata
3. Query CloudTrail for actual creation time

## References

- [AWS Tagging Best Practices](https://docs.aws.amazon.com/general/latest/gr/aws_tagging.html)
- [AWS Cost Explorer User Guide](https://docs.aws.amazon.com/cost-management/latest/userguide/ce-what-is.html)
- [Terraform AWS Provider default_tags](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#default_tags)
- [FinOps Foundation Framework](https://www.finops.org/framework/)
- [ADR 005: Cost Tracking Tags Strategy](adr/005-cost-tracking-tags-strategy.md)

## Revision History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-12-03 | 1.0 | Claude | Initial implementation of dual-layer tagging strategy |

---

**Questions or Issues?** See [ADR 005](adr/005-cost-tracking-tags-strategy.md) for architectural decisions and rationale.
