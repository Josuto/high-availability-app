# Cost Tracking and Tagging Strategy

**Last Updated:** 2026-01-07
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

**Location:** `infra-eks/deployment/*/provider.tf`
- Foundational infrastructure: `infra-eks/deployment/{backend,hosted_zone,ssl,ecr}/provider.tf`
- EKS-specific application infrastructure: `infra-eks/deployment/app/{vpc,eks_cluster,eks_node_group,aws_lb_controller,k8s_app,routing}/provider.tf`

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

**Location:** `infra-eks/modules/*/locals.tf`

**Benefits:**
- ✅ Module-level cost tracking
- ✅ Resource lifecycle tracking via timestamp
- ✅ Easy identification of resource origin
- ✅ Audit trail for compliance

## Standard Tags

| Tag | Example Value | Purpose | Required |
|-----|---------------|---------|----------|
| **Project** | `hademo` | Identifies project/application | ✅ Yes |
| **Environment** | `dev` or `prod` | Deployment environment | ✅ Yes |
| **ManagedBy** | `Terraform` | Infrastructure-as-Code tool | ✅ Yes |
| **Module** | `eks_cluster`, `eks_node_group`, `k8s_app` | Terraform module that created resource | ✅ Yes |
| **Owner** | `Platform Team` | Team responsible for resource | ✅ Yes |
| **CostCenter** | `Engineering` | For chargeback and budget allocation | ✅ Yes |
| **CreatedDate** | `2026-01-07T10:30:00Z` | Resource creation timestamp | ✅ Yes |
| **Name** | `eks-worker-node` | Human-readable resource name | ⚠️ Optional |

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
# Example: infra-eks/modules/eks_cluster/locals.tf
locals {
  cluster_name = "${var.environment}-${var.project_name}-eks-cluster"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Module      = "eks_cluster"
    CreatedDate = timestamp()
  }
}
```

### Module List

| Module | Module Tag Value | Resources Tagged |
|--------|------------------|------------------|
| `eks_cluster` | `eks_cluster` | EKS Cluster, IAM Roles, OIDC Provider, Security Groups |
| `eks_node_group` | `eks_node_group` | Managed Node Group, Launch Template, Auto Scaling Group, IAM Roles |
| `aws_lb_controller` | `aws_lb_controller` | IAM Role for IRSA, Kubernetes ServiceAccount |
| `k8s_app` | `k8s_app` | Kubernetes Deployment, Service, Ingress, HPA (limited AWS tag support) |
| `ecr` | `ecr` | ECR Repository |
| `ssl` | `ssl` | ACM Certificate, Route53 Validation Records |
| `hosted_zone` | `hosted_zone` | Route53 Hosted Zone |
| `routing` | `routing` | Route53 A Records (limited tag support) |

### Special Cases

#### EC2 Worker Nodes (EKS Node Group)

EC2 instances launched by the Managed Node Group require additional tags:

```hcl
locals {
  node_group_tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-${var.project_name}-worker-node"
      "kubernetes.io/cluster/${local.cluster_name}" = "owned"
    }
  )
}
```

**Critical Kubernetes Tags:**
- `kubernetes.io/cluster/${cluster_name}` = `owned` - Required for Cluster Autoscaler and other Kubernetes controllers to discover nodes

#### VPC Subnets (EKS-Specific)

Subnets require EKS-specific tags for AWS Load Balancer Controller discovery:

**Public Subnets:**
```hcl
public_subnet_tags = {
  "kubernetes.io/role/elb"                    = "1"
  "kubernetes.io/cluster/${cluster_name}"     = "shared"
}
```

**Private Subnets:**
```hcl
private_subnet_tags = {
  "kubernetes.io/role/internal-elb"           = "1"
  "kubernetes.io/cluster/${cluster_name}"     = "shared"
}
```

#### Resources Without Tag Support

Some AWS resources don't support tags:
- Route53 A/CNAME records
- Security Group Rules (SG only)

**Kubernetes Resources:**
Kubernetes resources (Deployments, Services, Pods, Ingresses) are managed via Terraform's Kubernetes provider but don't support AWS cost allocation tags. Costs are attributed to the underlying AWS resources (EC2 nodes, ALBs created by Ingress).

#### AWS Load Balancer Controller

ALBs created dynamically by the AWS Load Balancer Controller (via Kubernetes Ingress resources) inherit tags from the Ingress annotations:

```yaml
metadata:
  annotations:
    alb.ingress.kubernetes.io/tags: "Environment=prod,Project=myapp,Module=k8s_app,ManagedBy=Kubernetes"
```

## Cost Tracking in AWS

### AWS Cost Explorer Filters

Use these tags to filter costs in AWS Cost Explorer:

1. **By Environment:**
   - Tag Key: `Environment`
   - Tag Value: `dev` or `prod`
   - **Use Case:** Compare dev vs prod infrastructure costs

2. **By Project:**
   - Tag Key: `Project`
   - Tag Value: `hademo`
   - **Use Case:** Track total project spend

3. **By Module:**
   - Tag Key: `Module`
   - Tag Value: `eks_cluster`, `eks_node_group`, `k8s_app`, etc.
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
Filters: Project = hademo
```

**Query 2: Current Month Cost by Module**
```
Group By: Module
Time Period: This month
Filters: Environment = prod
```

**Query 3: EKS Control Plane vs Worker Nodes Cost**
```
Group By: Service
Time Period: Last 3 months
Filters:
  - Service = Amazon Elastic Kubernetes Service (control plane)
  - Service = Amazon Elastic Compute Cloud (worker nodes)
```

**Query 4: Spot vs On-Demand Node Cost Comparison**
```
Group By: Purchase Option
Time Period: This month
Filters:
  - Environment = dev
  - Resource Tags: Module = eks_node_group
```

## EKS-Specific Cost Breakdown

### Cost Components

| Component | Cost Driver | Approximate Monthly Cost | Notes |
|-----------|-------------|--------------------------|-------|
| **EKS Control Plane** | Per cluster | ~$72 | Fixed cost per cluster, regardless of size |
| **Worker Nodes (EC2)** | Instance hours | $30-$150+ | Depends on instance type, count, Spot vs On-Demand |
| **Application Load Balancer** | Per ALB + LCU hours | ~$16-$30 | Created by Ingress controller |
| **NAT Gateway** | Per gateway + data transfer | ~$32-$96 | Single (dev) vs Multi-AZ (prod) |
| **EBS Volumes** | GB-month | ~$5-$20 | Node root volumes (20GB dev, 40GB prod) |
| **Data Transfer** | GB transferred | Variable | Outbound internet traffic |
| **CloudWatch Logs** | GB ingested + storage | ~$5-$15 | EKS control plane and application logs |

### Environment Cost Comparison

| Environment | EKS Control Plane | Worker Nodes (2×t3.small) | ALB | NAT | Total Est. |
|-------------|-------------------|---------------------------|-----|-----|------------|
| **dev** (Spot) | $72 | ~$15 (70% discount) | $16 | $32 | **~$135/month** |
| **prod** (On-Demand) | $72 | ~$60 | $25 | $96 (3 AZs) | **~$253/month** |

**Note:** Spot instances in dev provide significant cost savings but can be interrupted with 2-minute notice.

### Cost Optimization Strategies for EKS

1. **Use Spot Instances for Non-Production**
   - Set `capacity_type = "SPOT"` in node group configuration
   - Savings: ~70% compared to On-Demand
   - Trade-off: Potential interruptions

2. **Right-Size Node Instances**
   - Use Kubernetes Vertical Pod Autoscaler (VPA) to analyze resource usage
   - Start with smaller instances (t3.small/t3.medium) and scale up as needed
   - Monitor node resource utilization via `kubectl top nodes`

3. **Enable Cluster Autoscaler**
   - Automatically scales worker nodes based on pod resource requests
   - Reduces costs by scaling down during low utilization periods
   - Already configured in this project's node group

4. **Optimize Pod Resource Requests**
   - Set realistic CPU and memory requests (not over-provisioning)
   - Use Horizontal Pod Autoscaler (HPA) to scale pods dynamically
   - Review resource limits to avoid node overcommitment

5. **Use Single NAT Gateway in Dev**
   - Already configured: `single_nat_gateway = true` for dev
   - Savings: ~$64/month compared to multi-AZ setup
   - Trade-off: Single point of failure for outbound traffic

6. **Leverage ECR Lifecycle Policies**
   - Automatically expire old Docker images
   - Dev: Keep only 3 tagged images
   - Prod: Keep 10 tagged images
   - Aggressive untagged image cleanup (keep only 1)

7. **Consider Fargate for Burst Workloads**
   - Pay only for pod vCPU and memory usage
   - No need to manage worker nodes
   - Good for CI/CD jobs or scheduled tasks

8. **Review ALB Usage**
   - Multiple Ingress resources can share a single ALB using IngressGroup annotation
   - Each ALB costs ~$16-30/month
   - Use ALB access logs to analyze traffic patterns

## FinOps Best Practices

### 1. Regular Cost Reviews

**Weekly:**
- Review anomalies via AWS Cost Anomaly Detection
- Check for untagged resources
- Monitor EKS control plane and worker node costs separately

**Monthly:**
- Cost by module analysis (especially `eks_cluster`, `eks_node_group`)
- Environment cost comparison (dev should be significantly < prod)
- Identify optimization opportunities (underutilized nodes, oversized pods)
- Review Spot instance interruption rates and savings

### 2. Tagging Compliance

**Automated Checks:**
```bash
# Run Terraform validation
cd infra-eks && ./run-tests.sh

# Check for missing tags (AWS CLI)
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=ManagedBy,Values=Terraform \
  --resource-type-filters ec2 eks elasticloadbalancing \
  --query 'ResourceTagMappingList[?length(Tags) < `7`]'
```

**Kubernetes Tag Verification:**
```bash
# Check if worker nodes have required tags
aws ec2 describe-instances \
  --filters "Name=tag:kubernetes.io/cluster/${CLUSTER_NAME},Values=owned" \
  --query 'Reservations[*].Instances[*].Tags'
```

**Manual Audits:**
- Quarterly review of all resources in AWS Console
- Verify tag consistency across regions
- Update tags for new resource types
- Ensure Ingress-created ALBs have proper tags

### 3. Cost Optimization

**Module-Level Analysis:**
```
1. Query: Cost by Module (last 30 days)
2. Identify highest cost modules
3. Investigate:
   - eks_cluster: Fixed cost, consider consolidating multiple clusters
   - eks_node_group: Right-size instances, use Spot for dev
   - k8s_app: Review pod resource requests/limits
   - aws_lb_controller: Consolidate ALBs across Ingress resources
```

**Kubernetes Resource Analysis:**
```bash
# Check node resource utilization
kubectl top nodes

# Check pod resource utilization
kubectl top pods --all-namespaces

# Check HPA status
kubectl get hpa --all-namespaces

# Analyze pod resource requests vs actual usage
kubectl describe nodes | grep -A 5 "Allocated resources"
```

**EKS-Specific Cost Analysis:**
```bash
# Get control plane cost (fixed)
aws pricing get-products \
  --service-code AmazonEKS \
  --filters Type=TERM_MATCH,Field=productFamily,Value=Compute

# Get worker node costs (variable)
aws ce get-cost-and-usage \
  --time-period Start=2026-01-01,End=2026-01-31 \
  --granularity MONTHLY \
  --metrics "BlendedCost" \
  --group-by Type=TAG,Key=Module \
  --filter file://filter.json
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
- GitHub Actions `test-eks-terraform-modules` job validates all modules
- Ensures `locals.tf` exists in each module
- Checks for tag consistency

### Audit Trail

All tagging changes are tracked via:
1. **Git History:** `infra-eks/modules/*/locals.tf` and `infra-eks/deployment/*/provider.tf`
2. **Terraform State:** State files record all tag values
3. **CloudTrail:** AWS API calls for tag updates

## Examples

### Example 1: EKS Cluster Tags

```hcl
# Provider adds (Layer 1):
{
  ManagedBy   = "Terraform"
  Environment = "prod"
  Project     = "hademo"
  Owner       = "Platform Team"
  CostCenter  = "Engineering"
}

# Module adds (Layer 2):
{
  Module      = "eks_cluster"
  CreatedDate = "2026-01-07T14:25:00Z"
}

# Final tags in AWS:
{
  ManagedBy   = "Terraform"
  Environment = "prod"
  Project     = "hademo"
  Owner       = "Platform Team"
  CostCenter  = "Engineering"
  Module      = "eks_cluster"
  CreatedDate = "2026-01-07T14:25:00Z"
}
```

### Example 2: EKS Worker Node Tags

```hcl
# Provider adds (Layer 1):
{
  ManagedBy   = "Terraform"
  Environment = "prod"
  Project     = "hademo"
  Owner       = "Platform Team"
  CostCenter  = "Engineering"
}

# Module adds (Layer 2):
{
  Module      = "eks_node_group"
  CreatedDate = "2026-01-07T14:30:00Z"
  Name        = "prod-myapp-worker-node"
  "kubernetes.io/cluster/prod-myapp-eks-cluster" = "owned"
}

# Final tags in AWS:
{
  ManagedBy   = "Terraform"
  Environment = "prod"
  Project     = "hademo"
  Owner       = "Platform Team"
  CostCenter  = "Engineering"
  Module      = "eks_node_group"
  CreatedDate = "2026-01-07T14:30:00Z"
  Name        = "prod-myapp-worker-node"
  "kubernetes.io/cluster/prod-myapp-eks-cluster" = "owned"
}
```

### Example 3: ALB Created by Ingress Controller

```yaml
# Kubernetes Ingress resource with ALB tags:
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  annotations:
    alb.ingress.kubernetes.io/tags: |
      Environment=prod,
      Project=myapp,
      Module=k8s_app,
      ManagedBy=Kubernetes,
      Owner=Platform Team,
      CostCenter=Engineering
```

**Resulting ALB tags in AWS:**
```hcl
{
  Environment = "prod"
  Project     = "myapp"
  Module      = "k8s_app"
  ManagedBy   = "Kubernetes"  # Note: Not "Terraform" for Ingress-created resources
  Owner       = "Platform Team"
  CostCenter  = "Engineering"
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

### Issue: Ingress-created ALB missing tags

**Solution:**
1. Verify Ingress annotation `alb.ingress.kubernetes.io/tags` is set correctly
2. Check AWS Load Balancer Controller logs:
   ```bash
   kubectl logs -n kube-system deployment/aws-load-balancer-controller
   ```
3. Ensure controller has proper IAM permissions to tag resources

### Issue: Kubernetes resources not showing in cost reports

**Expected Behavior:** Kubernetes resources (Deployments, Services, Pods) don't support AWS tags

**Cost Attribution:**
- Pod costs are attributed to the EC2 worker nodes they run on
- Use `kubectl top` commands to analyze resource usage by namespace/pod
- Implement Kubernetes labels for application-level cost tracking (separate from AWS tags)

### Issue: Spot instance interruptions causing cost spikes

**Solution:**
1. Review Spot interruption rate in AWS Console
2. Consider using mixed instance types (Spot + On-Demand)
3. Implement pod disruption budgets (PDB) for critical workloads
4. Use Cluster Autoscaler with multiple Spot instance types

## References

- [AWS Tagging Best Practices](https://docs.aws.amazon.com/general/latest/gr/aws_tagging.html)
- [AWS Cost Explorer User Guide](https://docs.aws.amazon.com/cost-management/latest/userguide/ce-what-is.html)
- [Terraform AWS Provider default_tags](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#default_tags)
- [EKS Best Practices - Cost Optimization](https://aws.github.io/aws-eks-best-practices/cost_optimization/)
- [AWS Load Balancer Controller - ALB Tagging](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/guide/ingress/annotations/#tags)
- [Kubernetes Resource Labels vs AWS Tags](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
- [FinOps Foundation Framework](https://www.finops.org/framework/)

## Revision History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-01-07 | 1.0 | Claude | Initial implementation of dual-layer tagging strategy for EKS infrastructure, adapted from ECS implementation with Kubernetes-specific considerations |

---

**Questions or Issues?** See the [EKS Infrastructure Documentation](../README.md) or [root README](../../README.md) for more information.
