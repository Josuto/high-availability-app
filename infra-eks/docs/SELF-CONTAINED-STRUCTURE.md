# Self-Contained EKS Infrastructure

This document explains why and how the `infra-eks/` directory is completely self-contained, requiring no dependencies on the `infra/` directory.

## Why Self-Contained?

The EKS infrastructure is **completely independent** from the ECS infrastructure for several important reasons:

### 1. **Maintainability**
- Clear separation of concerns - ECS and EKS don't interfere with each other
- Easy to understand what resources belong to each platform
- No confusion about which infrastructure you're working with

### 2. **Flexibility**
- Deploy EKS without needing ECS infrastructure
- Delete ECS infrastructure without affecting EKS
- Run both simultaneously for comparison or migration

### 3. **Memory & Documentation**
- After months, you won't need to remember "which resources are shared"
- Everything EKS needs is in `infra-eks/`
- Complete documentation stays with the code

### 4. **Portability**
- Copy `infra-eks/` to a new project and it works standalone
- No hidden dependencies on parent directory
- Self-documenting infrastructure

## Complete Directory Structure

```
infra-eks/                                      # Self-contained EKS infrastructure
│
├── modules/                                    # All required Terraform modules
│   ├── ecr/                                    # Container registry (copied from infra/)
│   ├── ssl/                                    # SSL/TLS certificates (copied from infra/)
│   ├── hosted_zone/                            # Route53 hosted zone (copied from infra/)
│   ├── eks_cluster/                            # EKS control plane (EKS-specific)
│   ├── eks_node_group/                         # EKS worker nodes (EKS-specific)
│   └── k8s_app/                     # Kubernetes app (EKS-specific)
│
├── deployment/                                 # All deployment configurations
│   │
│   ├── common.tfvars                           # Common variables
│   ├── backend-config.hcl                      # S3 backend config
│   ├── domain.tfvars                           # Domain configuration
│   │
│   ├── ecr/                                    # ECR deployment
│   │   ├── config.tf
│   │   ├── vars.tf
│   │   ├── outputs.tf
│   │   ├── provider.tf
│   │   └── backend.tf
│   │
│   ├── hosted_zone/                            # Route53 deployment
│   │   ├── config.tf
│   │   ├── vars.tf
│   │   ├── outputs.tf
│   │   ├── provider.tf
│   │   └── backend.tf
│   │
│   ├── ssl/                                    # SSL/TLS deployment
│   │   ├── config.tf
│   │   ├── vars.tf
│   │   ├── outputs.tf
│   │   ├── provider.tf
│   │   └── backend.tf
│   │
│   └── prod/                                   # Production environment
│       ├── vpc/                                # VPC deployment
│       │   ├── config.tf
│       │   ├── vars.tf
│       │   ├── outputs.tf
│       │   ├── provider.tf
│       │   └── backend.tf
│       │
│       ├── eks_cluster/                        # EKS cluster deployment
│       │   ├── config.tf
│       │   ├── vars.tf
│       │   ├── outputs.tf
│       │   ├── provider.tf
│       │   └── backend.tf
│       │
│       ├── eks_node_group/                     # EKS nodes deployment
│       │   ├── config.tf
│       │   ├── vars.tf
│       │   ├── outputs.tf
│       │   ├── provider.tf
│       │   └── backend.tf
│       │
│       └── k8s_app/                            # Kubernetes app deployment
│           ├── config.tf
│           ├── vars.tf
│           ├── outputs.tf
│           ├── provider.tf
│           └── backend.tf
│
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── hpa.yaml
│
├── scripts/                                    # Helper scripts
│
├── workflows/                                  # GitHub Actions workflows
│   ├── deploy_eks_infra.yaml
│   ├── destroy_eks_infra.yaml
│   └── README.md
│
└── documentation/                              # Complete documentation
    ├── GETTING-STARTED.md
    ├── README.md
    ├── QUICKSTART.md
    ├── ECS-vs-EKS-COMPARISON.md
    ├── DEPLOYMENT-APPROACHES.md
    ├── COMPLETE-IMPLEMENTATION-GUIDE.md
    └── SELF-CONTAINED-STRUCTURE.md (this file)
```

## Terraform State Organization

All EKS Terraform state files use the `deployment/` prefix to avoid conflicts with ECS:

```
S3 Bucket: your-terraform-state-bucket/
│
├── deployment/                         # ECS state (from infra/)
│   ├── prod/vpc/terraform.tfstate
│   ├── prod/alb/terraform.tfstate
│   ├── prod/ecs_cluster/terraform.tfstate
│   └── ...
│
└── deployment/                     # EKS state (from infra-eks/)
    ├── ecr/terraform.tfstate
    ├── hosted_zone/terraform.tfstate
    ├── ssl/terraform.tfstate
    ├── prod/
    │   ├── vpc/terraform.tfstate
    │   ├── eks_cluster/terraform.tfstate
    │   ├── eks_node_group/terraform.tfstate
    │   └── k8s_app/terraform.tfstate
    └── ...
```

**Key Point:** EKS uses its own VPC, ECR, and SSL resources - no sharing with ECS!

## Module Sources

All modules are referenced using relative paths within `infra-eks/`:

```hcl
# Example from deployment/app/eks_cluster/config.tf
module "eks_cluster" {
  source = "../../../modules/eks_cluster"  # Stays within infra-eks/
  # ...
}

# Example from deployment/ecr/config.tf
module "ecr" {
  source = "../../modules/ecr"  # Stays within infra-eks/
  # ...
}
```

**No references to `../../infra/` anywhere!**

## Remote State References

All remote state references point to state files within the `deployment/` prefix:

```hcl
# Example from deployment/app/eks_cluster/config.tf
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/app/vpc/terraform.tfstate"  # EKS VPC
  }
}

# Example from deployment/app/k8s_app/config.tf
data "terraform_remote_state" "ecr" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/ecr/terraform.tfstate"  # EKS ECR
  }
}
```

**All state references stay within `deployment/`!**

## Deployment Order

Deploy resources in this order (all within `infra-eks/`):

```bash
# 1. Foundation resources
cd infra-eks/deployment/hosted_zone && terraform apply
cd ../ecr && terraform apply
cd ../ssl && terraform apply
cd prod/vpc && terraform apply

# 2. EKS cluster and nodes
cd ../eks_cluster && terraform apply
cd ../eks_node_group && terraform apply

# 3. Install AWS Load Balancer Controller (manual step)
# See README.md for instructions

# 4. Kubernetes application
cd ../k8s_app && terraform apply
```

## Independent Resources

### EKS Has Its Own:

1. **VPC** - `infra-eks/deployment/app/vpc/`
   - CIDR: 10.0.0.0/16
   - 3 public subnets, 3 private subnets
   - Tagged for EKS and AWS Load Balancer Controller

2. **ECR** - `infra-eks/deployment/ecr/`
   - Container registry for Docker images
   - Separate from ECS's ECR (if it exists)

3. **SSL Certificate** - `infra-eks/deployment/ssl/`
   - ACM certificate for HTTPS
   - Validated via Route53

4. **Route53 Hosted Zone** - `infra-eks/deployment/hosted_zone/`
   - DNS management
   - Required for SSL validation

5. **EKS Cluster** - `infra-eks/deployment/app/eks_cluster/`
   - Kubernetes control plane
   - $72/month cost

6. **EKS Node Group** - `infra-eks/deployment/app/eks_node_group/`
   - Worker nodes (EC2 instances)
   - Auto-scaling configuration

7. **Kubernetes Application** - `infra-eks/deployment/app/k8s_app/`
   - Deployment, Service, Ingress, HPA
   - Creates ALB automatically

## No Shared Resources

Unlike the previous design where VPC, ECR, and ACM were shared between ECS and EKS, this self-contained implementation has:

- ❌ **No dependencies on `infra/`**
- ❌ **No shared state files**
- ❌ **No references to ECS resources**
- ✅ **Complete independence**
- ✅ **Can be deployed without ECS existing**
- ✅ **Can be copied to another project as-is**

## Configuration Files

All configuration is within `infra-eks/deployment/`:

### common.tfvars
```hcl
project_name = "terraform-course-dummy-nestjs-app"
environment  = "prod"
aws_region   = "eu-west-1"
```

### backend-config.hcl
```hcl
bucket = "YOUR_TERRAFORM_STATE_BUCKET_NAME"
# Used with: terraform init -backend-config=backend-config.hcl
```

### domain.tfvars
```hcl
root_domain               = "example.com"
```

## GitHub Actions Workflows

Workflows in `.github/workflows/eks/` are completely independent:

- **Trigger Paths**: Only trigger on `infra-eks/**` changes
- **State Paths**: Only reference `deployment/` states
- **No ECS Dependencies**: Don't check for ECS resources

To use workflows:
```bash
cp .github/workflows/eks/*.yaml .github/workflows/
```

## Documentation

All documentation is self-contained in `infra-eks/`:

| Document | Purpose |
|----------|---------|
| [GETTING-STARTED.md](GETTING-STARTED.md) | Entry point for new users |
| [README.md](README.md) | Complete EKS infrastructure guide |
| [QUICKSTART.md](QUICKSTART.md) | 30-minute deployment tutorial |
| [ECS-vs-EKS-COMPARISON.md](ECS-vs-EKS-COMPARISON.md) | Platform comparison |
| [DEPLOYMENT-APPROACHES.md](DEPLOYMENT-APPROACHES.md) | YAML vs Terraform |
| [COMPLETE-IMPLEMENTATION-GUIDE.md](COMPLETE-IMPLEMENTATION-GUIDE.md) | Everything explained |
| [SELF-CONTAINED-STRUCTURE.md](SELF-CONTAINED-STRUCTURE.md) | This document |

## Advantages of This Approach

### For Development
- ✅ Clone `infra-eks/` to a new repo → works immediately
- ✅ No confusion about which resources are shared
- ✅ Clear ownership of all components

### For Maintenance
- ✅ Delete `infra/` → EKS still works
- ✅ Update EKS → ECS not affected
- ✅ Debug issues → all code is local

### For Learning
- ✅ Study EKS in isolation
- ✅ Understand complete infrastructure
- ✅ No hidden dependencies to discover

### For Production
- ✅ Deploy to different AWS accounts
- ✅ Run multiple EKS clusters independently
- ✅ Scale without impacting other infrastructure

## Migration from Shared Resources (If Needed)

If you previously deployed EKS using shared resources from `infra/`, you can migrate to this self-contained structure:

### Step 1: Deploy New Infrastructure

```bash
cd infra-eks/deployment/hosted_zone && terraform apply
cd ../ecr && terraform apply
cd ../ssl && terraform apply
cd prod/vpc && terraform apply
```

### Step 2: Migrate Application

```bash
# Deploy new EKS cluster with new VPC
cd infra-eks/deployment/app/eks_cluster && terraform apply
cd ../eks_node_group && terraform apply

# Install Load Balancer Controller
# (Follow README.md)

# Deploy application using new ECR/ACM
cd ../k8s_app && terraform apply
```

### Step 3: Update DNS

Point your domain to the new ALB created by the new EKS cluster.

### Step 4: Destroy Old Infrastructure

```bash
# Destroy old EKS resources that used shared infra/
cd old-eks-deployment && terraform destroy
```

### Step 5: Clean Up

Old shared resources from `infra/` can now be used exclusively by ECS or destroyed if not needed.

## Summary

The `infra-eks/` directory is a **complete, standalone EKS infrastructure** that:

- 🎯 Requires **zero dependencies** on `infra/`
- 📁 Contains **all modules and deployments**
- 📚 Includes **comprehensive documentation**
- 🔧 Provides **helper scripts and workflows**
- 🚀 Can be **deployed independently**
- 📦 Can be **copied to other projects**
- 🧠 Is **easy to remember and maintain**

**Remember:** Everything you need for EKS is in `infra-eks/`. Nothing more, nothing less!

---

**Last Updated:** 2025-12-06
