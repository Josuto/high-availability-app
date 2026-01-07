# Shared Resources Between ECS and EKS

This document explains which infrastructure resources are shared between the ECS (`infra/`) and EKS (`infra-eks/`) implementations.

## Shared Resources

The following resources are deployed once and used by both ECS and EKS:

### 1. VPC and Networking
**Location:** [infra/deployment/app/vpc/](../../../infra/deployment/app/vpc/)

**What:** Virtual Private Cloud with public and private subnets

**State Path:** `deployment/app/vpc/terraform.tfstate`

**Outputs Used:**
- `vpc_id` - VPC identifier
- `vpc_private_subnets` - Private subnet IDs for EKS nodes
- `vpc_public_subnets` - Public subnet IDs for ALB
- `private_subnets` - Alternative name for private subnets

**Shared By:**
- ECS cluster nodes
- EKS cluster control plane and nodes
- Application Load Balancers (both ECS and EKS)

### 2. ECR (Elastic Container Registry)
**Location:** [infra/deployment/ecr/](../../../infra/deployment/ecr/)

**What:** Docker container registry for application images

**State Path:** `deployment/ecr/terraform.tfstate`

**Outputs Used:**
- `ecr_repository_url` - Full ECR repository URL (e.g., `123456789.dkr.ecr.eu-west-1.amazonaws.com/my-app`)
- `ecr_repository_name` - Repository name only

**Shared By:**
- ECS task definitions pull images from ECR
- EKS deployments pull images from ECR

**Note:** Both ECS and EKS pull from the same container registry.

### 3. ACM Certificate (SSL/TLS)
**Location:** [infra/deployment/ssl/](../../../infra/deployment/ssl/)

**What:** AWS Certificate Manager certificate for HTTPS

**State Path:** `deployment/ssl/terraform.tfstate`

**Outputs Used:**
- `acm_certificate_validation_arn` - ARN of the validated certificate

**Shared By:**
- ECS ALB HTTPS listeners
- EKS Ingress HTTPS configuration

**Note:** The same SSL certificate is used for both ECS and EKS load balancers.

## ECS-Specific Resources

These resources are only used by ECS:

### 4. Application Load Balancer (ECS)
**Location:** [infra/deployment/app/alb/](../../../infra/deployment/app/alb/)

**What:** ALB for ECS services with target groups

**State Path:** `deployment/app/alb/terraform.tfstate`

**Used By:** ECS services only

**Note:** EKS creates its own ALB dynamically via the AWS Load Balancer Controller when you deploy an Ingress resource.

### 5. ECS Cluster
**Location:** [infra/deployment/app/ecs_cluster/](../../../infra/deployment/app/ecs_cluster/)

**What:** ECS cluster with EC2 capacity provider

**State Path:** `deployment/app/ecs_cluster/terraform.tfstate`

**Used By:** ECS services only

### 6. ECS Service
**Location:** [infra/deployment/app/ecs_service/](../../../infra/deployment/app/ecs_service/)

**What:** ECS task definition and service

**State Path:** `deployment/app/ecs_service/terraform.tfstate`

**Used By:** ECS only

## EKS-Specific Resources

These resources are only used by EKS:

### 7. EKS Cluster
**Location:** [infra-eks/deployment-eks/prod/eks_cluster/](eks_cluster/)

**What:** EKS control plane

**State Path:** `deployment-eks/prod/eks_cluster/terraform.tfstate`

**Used By:** EKS only

### 8. EKS Node Group
**Location:** [infra-eks/deployment-eks/prod/eks_node_group/](eks_node_group/)

**What:** EKS worker nodes (EC2 instances)

**State Path:** `deployment-eks/prod/eks_node_group/terraform.tfstate`

**Used By:** EKS only

### 9. Kubernetes Application
**Location:** [infra-eks/deployment-eks/prod/k8s_app/](k8s_app/)

**What:** Kubernetes Deployment, Service, Ingress, HPA

**State Path:** `deployment-eks/prod/k8s_app/terraform.tfstate`

**Used By:** EKS only

**Note:** The Ingress creates an ALB automatically via the AWS Load Balancer Controller.

## Resource Dependency Graph

```
Shared Resources (infra/deployment/)
├── VPC (prod/vpc/)
│   ├── Used by ECS Cluster
│   ├── Used by ECS ALB
│   ├── Used by EKS Cluster
│   └── Used by EKS Nodes
│
├── ECR (ecr/)
│   ├── Used by ECS Task Definitions
│   └── Used by K8s Deployments
│
└── ACM Certificate (ssl/)
    ├── Used by ECS ALB
    └── Used by EKS Ingress

ECS Resources (infra/deployment/app/)
├── ALB (alb/)
│   └── References: VPC, ACM
├── ECS Cluster (ecs_cluster/)
│   └── References: VPC
└── ECS Service (ecs_service/)
    └── References: VPC, ALB, ECS Cluster, ECR

EKS Resources (infra-eks/deployment-eks/prod/)
├── EKS Cluster (eks_cluster/)
│   └── References: VPC
├── EKS Node Group (eks_node_group/)
│   └── References: VPC, EKS Cluster
└── K8s Application (k8s_app/)
    └── References: ECR, ACM, EKS Cluster
    └── Creates: ALB (via Ingress)
```

## Deployment Order

### Initial Setup (Shared Resources)
```bash
# 1. VPC (required first)
cd infra/deployment/app/vpc
terraform apply

# 2. ECR (independent)
cd ../../ecr
terraform apply

# 3. SSL/ACM (independent)
cd ../ssl
terraform apply
```

### ECS Deployment
```bash
# 4. ECS ALB
cd infra/deployment/app/alb
terraform apply

# 5. ECS Cluster
cd ../ecs_cluster
terraform apply

# 6. ECS Service
cd ../ecs_service
terraform apply
```

### EKS Deployment
```bash
# 4. EKS Cluster
cd infra-eks/deployment-eks/prod/eks_cluster
terraform apply

# 5. EKS Node Group
cd ../eks_node_group
terraform apply

# 6. Install AWS Load Balancer Controller
# (See README.md for installation steps)

# 7. K8s Application
cd ../k8s_app
terraform apply
```

## Cost Implications

### Shared Resources (Pay Once)
- **VPC:** FREE (only pay for NAT Gateway if used)
- **ECR:** ~$0.10/GB/month for storage
- **ACM Certificate:** FREE

### ECS-Specific Costs
- **ALB:** ~$16/month
- **EC2 Instances:** ~$60/month (2 × t3.medium)
- **Total ECS:** ~$76/month

### EKS-Specific Costs
- **EKS Control Plane:** $72/month
- **EC2 Instances:** ~$60/month (2 × t3.medium)
- **ALB (created by Ingress):** ~$16/month
- **Total EKS:** ~$148/month

### Running Both ECS and EKS
- **Shared Resources:** ~$0/month (negligible ECR storage)
- **ECS Resources:** ~$76/month
- **EKS Resources:** ~$148/month
- **Total Combined:** ~$224/month

**Note:** You can run both ECS and EKS simultaneously for testing/comparison, sharing VPC, ECR, and ACM.

## Remote State References

### In EKS Configurations

All EKS deployment configurations reference shared resources via remote state:

**Example from [eks_cluster/config.tf](eks_cluster/config.tf):**
```hcl
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/app/vpc/terraform.tfstate"  # ECS VPC
  }
}

module "eks_cluster" {
  source = "../../../modules/eks_cluster"

  vpc_id              = data.terraform_remote_state.vpc.outputs.vpc_id
  vpc_private_subnets = data.terraform_remote_state.vpc.outputs.vpc_private_subnets
  vpc_public_subnets  = data.terraform_remote_state.vpc.outputs.vpc_public_subnets
}
```

**Example from [k8s_app/config.tf](k8s_app/config.tf):**
```hcl
data "terraform_remote_state" "ecr" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/ecr/terraform.tfstate"  # Shared ECR
  }
}

data "terraform_remote_state" "acm" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/ssl/terraform.tfstate"  # Shared ACM
  }
}

module "k8s_app" {
  source = "../../../modules/k8s_app"

  ecr_repository_url  = data.terraform_remote_state.ecr.outputs.ecr_repository_url
  acm_certificate_arn = data.terraform_remote_state.acm.outputs.acm_certificate_validation_arn
}
```

## Separation of Concerns

### Why Share VPC, ECR, and ACM?

**VPC:**
- Cost-effective (avoid duplicating networking infrastructure)
- Simplified inter-service communication
- Consistent security groups and network policies

**ECR:**
- Single source of truth for container images
- Shared image cache (faster pulls)
- Consistent image versioning across platforms

**ACM Certificate:**
- Single domain certificate works for both platforms
- Simplified certificate management
- No need to duplicate SSL/TLS infrastructure

### Why Separate ALBs?

**ECS ALB:**
- Manually created via Terraform
- Static target groups
- Tight integration with ECS services

**EKS ALB:**
- Dynamically created by AWS Load Balancer Controller
- Created from Kubernetes Ingress resources
- Kubernetes-native management

**Benefit:** Each platform manages its own load balancing in the way that's most natural for that platform.

## Migration Scenarios

### Scenario 1: Migrate from ECS to EKS

```bash
# 1. Keep ECS running (no changes)

# 2. Deploy EKS alongside ECS
cd infra-eks/deployment-eks/prod/eks_cluster && terraform apply
cd ../eks_node_group && terraform apply
cd ../k8s_app && terraform apply

# 3. Test EKS deployment
curl https://<eks-alb-url>

# 4. Update DNS to point to EKS ALB

# 5. Decommission ECS
cd infra/deployment/app/ecs_service && terraform destroy
cd ../ecs_cluster && terraform destroy
cd ../alb && terraform destroy

# 6. Keep shared resources (VPC, ECR, ACM)
```

### Scenario 2: Run Both Platforms Simultaneously

```bash
# Use weighted DNS routing or path-based routing
# - 90% traffic to ECS (stable)
# - 10% traffic to EKS (testing)

# Both platforms share:
# - VPC (same networking)
# - ECR (same container images)
# - ACM (same SSL certificate)

# Each platform has:
# - Own compute resources
# - Own load balancer
```

## Summary

| Resource | Path | Shared? | State Key |
|----------|------|---------|-----------|
| **VPC** | infra/deployment/app/vpc/ | ✅ Yes | deployment/app/vpc/terraform.tfstate |
| **ECR** | infra/deployment/ecr/ | ✅ Yes | deployment/ecr/terraform.tfstate |
| **ACM** | infra/deployment/ssl/ | ✅ Yes | deployment/ssl/terraform.tfstate |
| **ECS ALB** | infra/deployment/app/alb/ | ❌ ECS Only | deployment/app/alb/terraform.tfstate |
| **ECS Cluster** | infra/deployment/app/ecs_cluster/ | ❌ ECS Only | deployment/app/ecs_cluster/terraform.tfstate |
| **ECS Service** | infra/deployment/app/ecs_service/ | ❌ ECS Only | deployment/app/ecs_service/terraform.tfstate |
| **EKS Cluster** | infra-eks/deployment-eks/prod/eks_cluster/ | ❌ EKS Only | deployment-eks/prod/eks_cluster/terraform.tfstate |
| **EKS Nodes** | infra-eks/deployment-eks/prod/eks_node_group/ | ❌ EKS Only | deployment-eks/prod/eks_node_group/terraform.tfstate |
| **K8s App** | infra-eks/deployment-eks/prod/k8s_app/ | ❌ EKS Only | deployment-eks/prod/k8s_app/terraform.tfstate |

---

**Key Takeaway:** VPC, ECR, and ACM are shared infrastructure. ECS and EKS each have their own compute and load balancing resources. This allows you to run both platforms simultaneously while minimizing cost and complexity.
