# ADR 005: Cost Tracking Tags Strategy

## Status
Accepted

## Context
Our AWS infrastructure spans multiple modules and environments (dev/prod) without a comprehensive tagging strategy. This creates challenges for:

1. **Cost Attribution:** Unable to determine which team/project/module drives costs
2. **Resource Management:** Difficult to identify resource ownership and lifecycle
3. **FinOps Practices:** Cannot implement chargeback or showback models
4. **Compliance:** Audit trails require clear resource ownership
5. **Optimization:** Hard to identify expensive components for cost reduction

### Current State (Before Implementation)

**Existing Tags:**
- `Project`: Inconsistently applied
- `Environment`: Applied to most resources
- **Missing:** ManagedBy, Module, Owner, CostCenter, CreatedDate

**Problems:**
- No centralized tagging mechanism
- Manual tagging prone to errors
- Tag drift across resources
- No cost center attribution
- No module-level cost tracking

### Requirements

From Issue #9, Task 5.4:
- ✅ All resources must have complete tag set
- ✅ Tags visible in AWS Cost Explorer
- ✅ Can filter costs by environment, project, owner
- ✅ Enable chargeback and showback reporting

## Decision
We will implement a **dual-layer tagging architecture** using:

1. **AWS Provider default_tags** for organization-wide tags
2. **Module-level locals.tf** for module-specific tags
3. **Seven standard tags** for all resources

### Standard Tags

| Tag | Source | Purpose | Example Value |
|-----|--------|---------|---------------|
| `ManagedBy` | Provider | IaC tool identification | `Terraform` |
| `Environment` | Provider | Deployment stage | `dev`, `prod` |
| `Project` | Provider | Project identifier | `terraform-course-dummy-nestjs-app` |
| `Owner` | Provider | Team ownership | `Platform Team` |
| `CostCenter` | Provider | Chargeback allocation | `Engineering` |
| `Module` | Module | Terraform module | `alb`, `ecs_cluster` |
| `CreatedDate` | Module | Resource creation timestamp | `2025-12-03T10:30:00Z` |

### Implementation Approach

**Layer 1: Provider Default Tags**

All `provider.tf` files in `infra/deployment/*/` configured with:

```hcl
provider "aws" {
  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = var.environment
      Project     = var.project_name
      Owner       = "Platform Team"
      CostCenter  = "Engineering"
    }
  }
}
```

**Layer 2: Module-Specific Tags**

Each module in `infra/modules/*/` gets a `locals.tf` file:

```hcl
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Module      = "module_name"
    CreatedDate = timestamp()
  }
}
```

Resources then use: `tags = local.common_tags`

## Alternatives Considered

### Alternative 1: Single-Layer Tagging (Module-Only)

**Description:** Only add tags at the module level, skip provider default_tags

**Pros:**
- Simpler implementation
- Single source of truth
- More flexibility per module

**Cons:**
- Higher chance of human error
- Tag drift if developer forgets to add tags
- No guarantee of organizational tags (Owner, CostCenter)
- More maintenance burden (update 8 modules vs 9 provider files)

**Verdict:** Rejected - Provider default_tags provide better guarantees

### Alternative 2: Single-Layer Tagging (Provider-Only)

**Description:** Only use provider default_tags, no module-specific tags

**Pros:**
- Maximum simplicity
- Guaranteed consistency
- Zero manual tagging

**Cons:**
- Cannot track module-level costs
- No resource creation timestamps
- No way to identify which module created a resource
- Loses granularity needed for cost optimization

**Verdict:** Rejected - Module tracking is essential for FinOps

### Alternative 3: External Tagging Tool (e.g., Tag Editor, AWS Config)

**Description:** Use AWS Tag Editor or AWS Config Rules to enforce tags post-creation

**Pros:**
- Centralized tag management
- Can tag resources created outside Terraform
- Drift detection

**Cons:**
- Additional AWS costs (Config Rules)
- Reactive (tags applied after resource creation)
- Doesn't prevent untagged resources during creation
- Complexity of managing another tool
- Tags not in Terraform state

**Verdict:** Rejected - Proactive tagging at creation is better

### Alternative 4: Hardcoded CreatedDate

**Description:** Replace `timestamp()` with manually set creation date

**Pros:**
- Immutable timestamp
- Doesn't change on terraform apply
- True resource birthday

**Cons:**
- Manual effort for each resource
- Prone to human error
- Harder to maintain
- Lost automation benefit

**Verdict:** Rejected - Accept timestamp() trade-off (see Consequences)

### Alternative 5: Minimal Tags (Project + Environment Only)

**Description:** Only tag with Project and Environment, skip others

**Pros:**
- Minimal implementation
- Covers basic cost filtering

**Cons:**
- Cannot do chargeback (no CostCenter)
- Cannot identify ownership (no Owner)
- Cannot track IaC tool (no ManagedBy)
- Cannot identify module costs (no Module)
- Limited FinOps capabilities

**Verdict:** Rejected - Insufficient for enterprise requirements

## Rationale

### Why Dual-Layer Architecture?

**Provider Layer (Global Tags):**
- ✅ Guaranteed organizational governance
- ✅ No way to forget critical tags (Owner, CostCenter)
- ✅ Consistent across all resources
- ✅ Single place to update org-wide tags

**Module Layer (Granular Tags):**
- ✅ Module-level cost tracking
- ✅ Resource lifecycle information
- ✅ Troubleshooting (which module created this?)
- ✅ Cost optimization targets

**Together:**
- ✅ Best of both worlds
- ✅ Separation of concerns (org vs module)
- ✅ Flexibility + Consistency

### Tag Selection Rationale

| Tag | Why Required | Business Value |
|-----|--------------|----------------|
| **ManagedBy** | Distinguish Terraform vs manual/CDK resources | Change management, automation tracking |
| **Environment** | Cost comparison (dev should be < prod) | Environment-based budgets, alerts |
| **Project** | Multi-project AWS accounts | Project-level cost attribution |
| **Owner** | Accountability and contact point | Incident response, cost accountability |
| **CostCenter** | Chargeback to departments | Budget allocation, financial reporting |
| **Module** | Identify cost drivers within project | Optimization targets (e.g., ALB vs ECS) |
| **CreatedDate** | Resource age for lifecycle policies | Identify old/orphaned resources |

### Why timestamp() Despite Mutability?

**Problem:** `timestamp()` updates on every `terraform apply`

**Why We Accept It:**
1. **First apply is accurate** - Initial creation date is correct
2. **Approximate age is useful** - "Created ~6 months ago" vs exact date
3. **Can cross-reference CloudTrail** - For exact creation time if needed
4. **Automation > Accuracy** - Better than manual timestamps prone to error
5. **Simple implementation** - No external tools or state management

**Mitigation:** Document behavior in [COST_TRACKING.md](../COST_TRACKING.md)

## Consequences

### Positive

1. **Complete Cost Visibility**
   - Can filter by any tag in AWS Cost Explorer
   - Module-level cost attribution enables optimization
   - Environment cost comparison (dev vs prod)

2. **Chargeback Capability**
   - CostCenter tag enables departmental chargeback
   - Owner tag provides team accountability
   - Project tag allows multi-project accounts

3. **Operational Excellence**
   - ManagedBy identifies IaC-managed resources
   - Module tag aids troubleshooting
   - CreatedDate helps identify orphaned resources

4. **Automated Compliance**
   - Provider default_tags guarantee organizational tags
   - Terraform state tracks all tag changes
   - Git history provides audit trail

5. **Developer Experience**
   - Simple to use: `tags = local.common_tags`
   - No manual tag management per resource
   - Consistent pattern across all modules

### Negative

1. **CreatedDate Mutability**
   - Timestamp changes on every apply
   - Not suitable for strict audit requirements
   - **Mitigation:** Document behavior, use CloudTrail for exact dates

2. **Tag Redundancy**
   - Some tags appear in both layers (Project, Environment, ManagedBy)
   - Module layer overrides provider layer for these
   - **Mitigation:** Acceptable trade-off for consistency

3. **Initial Migration Effort**
   - Must update all 8 modules + 9 provider files
   - Requires testing to ensure no disruption
   - **Mitigation:** One-time cost, automated with scripts

4. **Tag Propagation Delay**
   - Cost Explorer tags visible after 24 hours
   - Cannot immediately query new tags
   - **Mitigation:** Plan ahead, document delay

### Neutral

1. **Tag Costs**
   - AWS doesn't charge for tags
   - Cost Explorer queries are free
   - No financial impact

2. **Tag Limits**
   - AWS limit: 50 tags per resource
   - We use 7 tags (14% of limit)
   - Plenty of room for future tags

3. **Terraform State Size**
   - Tags increase state file size
   - Impact is negligible (few KB per resource)
   - State files remain manageable

## Implementation

### Rollout Plan

**Phase 1: Module Updates (Day 1)**
1. Create `locals.tf` for all 8 modules
2. Update resource tags to use `local.common_tags`
3. Test in dev environment

**Phase 2: Provider Updates (Day 1)**
1. Update all 9 `provider.tf` files with `default_tags`
2. Validate with `terraform plan`
3. Apply to dev environment

**Phase 3: Production Deployment (Day 2)**
1. Review dev environment tags in AWS Console
2. Apply to prod environment
3. Monitor for issues

**Phase 4: AWS Configuration (Day 3)**
1. Enable Cost Allocation Tags in AWS Billing Console
2. Activate all 7 tags
3. Wait 24 hours for propagation

**Phase 5: Validation (Day 4)**
1. Verify tags in Cost Explorer
2. Create sample cost reports
3. Document any issues

### Verification Steps

```bash
# Step 1: Validate Terraform configurations
cd infra && terraform validate

# Step 2: Check for untagged resources (after apply)
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=ManagedBy,Values=Terraform \
  --resource-type-filters ec2 ecs elasticloadbalancing \
  --query 'ResourceTagMappingList[?length(Tags) < `7`]'

# Step 3: List all tags for a sample resource
aws elbv2 describe-load-balancers \
  --names prod-terraform-course-dummy-nestjs-app-alb \
  --query 'LoadBalancers[0].Tags'
```

### Files Changed

**New Files:**
- `infra/modules/alb/locals.tf`
- `infra/modules/ecr/locals.tf`
- `infra/modules/ecs_cluster/locals.tf`
- `infra/modules/ecs_service/locals.tf`
- `infra/modules/ssl/locals.tf`
- `infra/modules/hosted_zone/locals.tf`
- `infra/modules/alb_rule/locals.tf`
- `docs/COST_TRACKING.md`
- `docs/adr/005-cost-tracking-tags-strategy.md` (this file)

**Note:** The `routing` module does not have a `locals.tf` file because Route53 A/CNAME records do not support tags in AWS.

**Modified Files:**
- All `*.tf` files in `infra/modules/*/` (tag blocks updated)
- All `provider.tf` files in `infra/deployment/*/` (default_tags added)

## Monitoring and Maintenance

### Monthly Tasks

1. **Cost Review Meeting**
   - Review Cost Explorer reports by Module
   - Identify cost anomalies
   - Discuss optimization opportunities

2. **Tag Compliance Check**
   - Run AWS CLI command to find untagged resources
   - Investigate and remediate

3. **Documentation Updates**
   - Update COST_TRACKING.md with new insights
   - Add cost optimization wins to runbook

### Quarterly Tasks

1. **Tag Strategy Review**
   - Evaluate if current tags meet needs
   - Consider additional tags if needed
   - Review tag value consistency

2. **Cost Optimization**
   - Deep dive into highest-cost modules
   - Right-size resources based on utilization
   - Update ADR with decisions

### Annual Tasks

1. **FinOps Maturity Assessment**
   - Benchmark against FinOps Foundation framework
   - Identify gaps in cost management
   - Plan improvements for next year

## Future Enhancements

### Potential Additional Tags (Not Implemented)

| Tag | Purpose | Why Not Included |
|-----|---------|------------------|
| `BackupPolicy` | Backup schedule identifier | Not needed yet, no backup automation |
| `Compliance` | Compliance framework (PCI, HIPAA) | No compliance requirements currently |
| `DataClassification` | Data sensitivity level | No sensitive data handling yet |
| `MaintenanceWindow` | When updates can occur | No automated maintenance yet |
| `Version` | Application/module version | Complex to maintain, Git provides this |

**Decision:** Add these tags when requirements arise, not preemptively

### Integration Opportunities

**AWS Cost Anomaly Detection:**
- Enable anomaly detection
- Configure alerts by CostCenter or Module
- Investigate anomalies in weekly reviews

**Third-Party Cost Tools:**
- CloudHealth/CloudCheckr integration
- Custom dashboards using tags
- Automated reporting pipelines

**Terraform Cloud:**
- Cost estimation with tags
- Policy-as-Code for tag enforcement
- Sentinel policies for required tags

## References

- **AWS Documentation:**
  - [Tagging Best Practices](https://docs.aws.amazon.com/general/latest/gr/aws_tagging.html)
  - [Cost Allocation Tags](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-alloc-tags.html)
  - [Provider default_tags](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#default_tags)

- **FinOps Resources:**
  - [FinOps Foundation Framework](https://www.finops.org/framework/)
  - [Cloud Cost Optimization Playbook](https://www.finops.org/resources/cloud-cost-optimization/)

- **Project Documentation:**
  - [Cost Tracking Guide](../COST_TRACKING.md) - Operational guide for using tags
  - [Issue #9 Task 5.4](https://github.com/anthropics/terraform-course-dummy-nestjs-app/issues/9) - Original requirements

## Revision History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-12-03 | 1.0 | Claude | Initial ADR documenting dual-layer tagging strategy |

## Notes

This ADR documents a **pragmatic approach** to cost tracking that balances:
- ✅ Comprehensive tagging for FinOps needs
- ✅ Developer ease of use (automated tagging)
- ✅ Governance (provider default_tags)
- ✅ Granularity (module-level tracking)

**Key Insight:** The dual-layer approach provides both organizational governance (provider tags) and operational flexibility (module tags) without developer burden.

**Trade-off Accepted:** CreatedDate timestamp mutability is an acceptable compromise for automation benefits. For strict audit requirements, CloudTrail provides exact creation times.
