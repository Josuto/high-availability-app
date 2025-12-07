# Kubernetes Deployment Approaches: YAML vs Terraform

This document explains the relationship between the two different approaches for deploying Kubernetes applications in this repository.

## Overview

This repository provides **two alternative approaches** for deploying the same Kubernetes resources:

1. **[k8s-manifests/](k8s-manifests/)** - Raw YAML manifests deployed with `kubectl`
2. **[modules/k8s_app_deployment/](modules/k8s_app_deployment/)** - Terraform module using the Kubernetes provider

Both deploy the exact same resources (Deployment, Service, Ingress, HPA), just using different tools.

## The Two Approaches

### Approach 1: Raw YAML Manifests (k8s-manifests/)

**Location:** [k8s-manifests/](k8s-manifests/)

**Files:**
- [deployment.yaml](k8s-manifests/deployment.yaml) - Application deployment
- [service.yaml](k8s-manifests/service.yaml) - Kubernetes service
- [ingress.yaml](k8s-manifests/ingress.yaml) - ALB ingress configuration
- [hpa.yaml](k8s-manifests/hpa.yaml) - Horizontal Pod Autoscaler

**Deployment Method:**
```bash
# After EKS cluster is ready
kubectl apply -f infra-eks/k8s-manifests/
```

**Characteristics:**
- ✅ Pure Kubernetes-native approach
- ✅ Simple, direct YAML manifests
- ✅ Uses standard `kubectl` CLI
- ✅ GitOps-friendly (ArgoCD, FluxCD)
- ✅ No Terraform state for K8s resources
- ✅ Industry standard approach
- ✅ Portable across cloud providers
- ⚠️ Manual value replacement needed (ECR URL, certificate ARN)
- ⚠️ No automatic integration with Terraform outputs
- ⚠️ Separate deployment workflow from infrastructure

**Prerequisites:**
1. Update ECR repository URL in [deployment.yaml:16](k8s-manifests/deployment.yaml#L16)
2. Update ACM certificate ARN in [ingress.yaml:12](k8s-manifests/ingress.yaml#L12)
3. Install AWS Load Balancer Controller

**Example Workflow:**
```bash
# 1. Deploy EKS infrastructure with Terraform
cd infra-eks/deployment/prod/eks_cluster
terraform apply

cd ../eks_node_group
terraform apply

# 2. Install AWS Load Balancer Controller
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --set clusterName=prod-terraform-course-dummy-nestjs-app-eks-cluster

# 3. Update manifests with your values
# Edit k8s-manifests/deployment.yaml - replace <ECR_REPOSITORY_URL>
# Edit k8s-manifests/ingress.yaml - replace <ACM_CERTIFICATE_ARN>

# 4. Deploy application
kubectl apply -f infra-eks/k8s-manifests/

# 5. Verify deployment
kubectl get deployments
kubectl get services
kubectl get ingress
kubectl get hpa
```

### Approach 2: Terraform Kubernetes Provider (modules/k8s_app_deployment/)

**Location:**
- Module: [modules/k8s_app_deployment/](modules/k8s_app_deployment/)
- Deployment: [deployment/prod/k8s_app/](deployment/prod/k8s_app/)

**Module Files:**
- [main.tf](modules/k8s_app_deployment/main.tf) - Kubernetes Deployment resource
- [service.tf](modules/k8s_app_deployment/service.tf) - Kubernetes Service resource
- [ingress.tf](modules/k8s_app_deployment/ingress.tf) - Kubernetes Ingress resource
- [hpa.tf](modules/k8s_app_deployment/hpa.tf) - HPA resource
- [vars.tf](modules/k8s_app_deployment/vars.tf) - Input variables
- [outputs.tf](modules/k8s_app_deployment/outputs.tf) - Module outputs
- [locals.tf](modules/k8s_app_deployment/locals.tf) - Common tags and labels
- [versions.tf](modules/k8s_app_deployment/versions.tf) - Provider versions

**Deployment Method:**
```bash
cd infra-eks/deployment/prod/k8s_app
terraform init
terraform apply
```

**Characteristics:**
- ✅ Unified Terraform workflow for infrastructure + apps
- ✅ Automatic integration with Terraform remote state
- ✅ Environment-specific variables and configurations
- ✅ Type safety and validation
- ✅ Automatic value substitution (ECR URL, certificate ARN)
- ✅ Infrastructure and application managed together
- ✅ Consistent tagging across all resources
- ⚠️ Requires Terraform knowledge
- ⚠️ Kubernetes resources stored in Terraform state
- ⚠️ Less common in Kubernetes-native organizations
- ⚠️ Not GitOps-friendly without additional tooling

**Prerequisites:**
1. Update S3 bucket name in [deployment/prod/k8s_app/backend.tf:2](deployment/prod/k8s_app/backend.tf#L2)
2. Set `state_bucket_name` variable
3. Install AWS Load Balancer Controller (same as Approach 1)

**Example Workflow:**
```bash
# 1. Deploy EKS infrastructure with Terraform
cd infra-eks/deployment/prod/eks_cluster
terraform apply

cd ../eks_node_group
terraform apply

# 2. Install AWS Load Balancer Controller
# (same as Approach 1)

# 3. Deploy application with Terraform
cd ../k8s_app

# Update backend.tf with your S3 bucket name
# Set variables in terraform.tfvars or via CLI

terraform init
terraform apply

# 4. Get outputs
terraform output alb_url
terraform output application_url
```

## Comparison Matrix

| Aspect | k8s-manifests/ (YAML) | k8s_app_deployment (Terraform) |
|--------|----------------------|--------------------------------|
| **Deployment Tool** | `kubectl` | `terraform` |
| **Configuration Format** | YAML | HCL (Terraform) |
| **Remote State Integration** | Manual placeholders | Automatic via `data` sources |
| **ECR URL** | Hardcoded - must edit | Auto-fetched from ECR state |
| **Certificate ARN** | Hardcoded - must edit | Auto-fetched from ACM state |
| **Environment-specific** | Need multiple YAML files | Single module with variables |
| **State Management** | Kubernetes API | Terraform state file |
| **GitOps Compatible** | ✅ Native support | ⚠️ Requires extra tooling |
| **Learning Curve** | Lower (standard YAML) | Higher (HCL + K8s + Terraform) |
| **Industry Practice** | ⭐ Very common | Less common |
| **Portability** | Any K8s cluster | Tied to Terraform workflow |
| **Version Control** | Direct YAML diffs | Terraform plan diffs |
| **Rollback** | `kubectl rollout undo` | `terraform apply` previous state |
| **Debugging** | `kubectl describe/logs` | Same + `terraform state` |

## Decision Guide

### Choose **k8s-manifests/** (YAML) if you:

✅ Want to follow **Kubernetes best practices** - Most K8s organizations use YAML
✅ Plan to use **GitOps** - ArgoCD, FluxCD work natively with YAML
✅ Have **separate teams** - Infra team (Terraform) + App team (YAML)
✅ Need **portability** - YAML works on any K8s cluster (GKE, AKS, on-prem)
✅ Are **learning Kubernetes** - YAML is the standard teaching format
✅ Want **native K8s tooling** - kubectl, kustomize, helm
✅ Prefer **declarative configuration** stored in Git

**Typical Organizations:**
- Kubernetes-native startups
- Companies with dedicated platform teams
- Organizations using service mesh (Istio, Linkerd)
- Teams using GitOps workflows

**Workflow Example:**
```
Infrastructure Team (Terraform)     Application Team (YAML)
├── VPC                             ├── Deployments
├── EKS Cluster                     ├── Services
├── Node Groups                     ├── Ingress
├── IAM Roles                       ├── ConfigMaps
└── Security Groups                 └── Secrets
```

### Choose **k8s_app_deployment** (Terraform) if you:

✅ Want **unified tooling** - Everything deployed with Terraform
✅ Have a **small team** - Same people manage infrastructure and apps
✅ Want **automatic integration** - ECR, ACM, EKS outputs auto-connected
✅ Prefer **type safety** - Terraform validates before deployment
✅ Are **Terraform-heavy** - Organization standardizes on Terraform
✅ Need **unified state management** - All resources in Terraform state
✅ Want **consistent tagging** - Same tagging strategy across all layers

**Typical Organizations:**
- Small to medium startups (<20 engineers)
- AWS-centric shops
- Infrastructure-as-code first companies
- Teams without dedicated K8s expertise

**Workflow Example:**
```
Single Team (All Terraform)
├── VPC                  (terraform apply)
├── EKS Cluster          (terraform apply)
├── Node Groups          (terraform apply)
├── Applications         (terraform apply)
└── Monitoring           (terraform apply)
```

## Detailed Feature Comparison

### Remote State Integration

**YAML Approach:**
```yaml
# deployment.yaml
spec:
  template:
    spec:
      containers:
      - name: nestjs
        image: <ECR_REPOSITORY_URL>:latest  # ⚠️ Manual replacement needed
```

**Terraform Approach:**
```hcl
# config.tf
data "terraform_remote_state" "ecr" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/prod/ecr/terraform.tfstate"
  }
}

module "k8s_app" {
  source = "../../../modules/k8s_app_deployment"
  ecr_repository_url = data.terraform_remote_state.ecr.outputs.ecr_repository_url  # ✅ Automatic
}
```

### Environment-Specific Configuration

**YAML Approach:**
```bash
# Need separate files or kustomize overlays
k8s-manifests/
├── base/
│   ├── deployment.yaml
│   └── service.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml
    └── prod/
        └── kustomization.yaml
```

**Terraform Approach:**
```hcl
# Single module with variables
variable "replica_count" {
  type = map(number)
  default = {
    dev  = 2
    prod = 3
  }
}

replica_count = var.replica_count[var.environment]
```

### Resource Limits by Environment

**YAML Approach:**
```yaml
# Need separate files for each environment
# prod-deployment.yaml
resources:
  limits:
    memory: "1024Mi"
    cpu: "500m"

# dev-deployment.yaml
resources:
  limits:
    memory: "512Mi"
    cpu: "250m"
```

**Terraform Approach:**
```hcl
# Single configuration
variable "memory_limit" {
  type = map(string)
  default = {
    dev  = "512Mi"
    prod = "1024Mi"
  }
}
```

## Hybrid Approach (Best of Both Worlds)

You can combine both approaches:

### Strategy 1: Terraform Generates YAML

Use Terraform to template YAML files with dynamic values:

```hcl
# generate-manifests.tf
resource "local_file" "deployment" {
  filename = "${path.module}/generated/deployment.yaml"
  content = templatefile("${path.module}/templates/deployment.yaml.tpl", {
    ecr_url        = data.terraform_remote_state.ecr.outputs.ecr_repository_url
    image_tag      = var.image_tag
    replica_count  = var.replica_count[var.environment]
    memory_limit   = var.memory_limit[var.environment]
    cpu_limit      = var.cpu_limit[var.environment]
  })
}

resource "null_resource" "apply_manifests" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/generated/"
  }

  depends_on = [local_file.deployment]
}
```

**Benefits:**
- ✅ Automatic value substitution from Terraform
- ✅ Keep YAML as deployment format
- ✅ Single source of truth for variables
- ✅ GitOps-compatible (commit generated YAML)

### Strategy 2: Terraform for Infrastructure, YAML for Apps

**Recommended for Most Teams:**

1. **Terraform** - EKS cluster, node groups, IAM, VPC (long-lived infrastructure)
2. **YAML + kubectl** - Application deployments (frequently changing)

```bash
# Infrastructure team
cd infra-eks/deployment/prod/eks_cluster && terraform apply
cd ../eks_node_group && terraform apply

# Application team
kubectl apply -f infra-eks/k8s-manifests/
```

### Strategy 3: GitOps with Terraform Backend

Use Terraform for infrastructure, GitOps for applications:

1. **Terraform** - EKS cluster, node groups
2. **ArgoCD/FluxCD** - Automatically deploys YAML from Git

```yaml
# argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nestjs-app
spec:
  source:
    repoURL: https://github.com/your-org/repo
    path: infra-eks/k8s-manifests
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: default
```

## Real-World Usage Patterns

### Pattern 1: Kubernetes-Native Organization (YAML)

```
Team Structure:
├── Platform Team
│   └── Manages: EKS cluster (Terraform)
└── Product Teams (5-10 teams)
    └── Manages: Applications (YAML + kubectl/GitOps)

Deployment:
1. Platform team: terraform apply (EKS infrastructure)
2. Product teams: git push → ArgoCD auto-deploys
```

**Examples:** Airbnb, Shopify, Spotify

### Pattern 2: Small DevOps Team (Terraform)

```
Team Structure:
└── DevOps Team (2-5 engineers)
    └── Manages: Everything (Terraform)

Deployment:
1. terraform apply (EKS cluster)
2. terraform apply (node groups)
3. terraform apply (applications)
```

**Examples:** Early-stage startups, AWS-centric companies

### Pattern 3: Hybrid Approach

```
Team Structure:
├── Infrastructure Team
│   └── Manages: Core infrastructure (Terraform)
└── Platform Team
    └── Manages: Applications (YAML + GitOps)

Deployment:
1. Infra team: terraform apply (EKS, networking, security)
2. Platform team: ArgoCD syncs YAML from Git
```

**Examples:** Medium to large companies (100+ engineers)

## Migration Path

### From YAML to Terraform

If you start with YAML and want to move to Terraform:

```bash
# 1. Import existing resources
terraform import kubernetes_deployment.app default/nestjs-app-deployment
terraform import kubernetes_service.app default/nestjs-app-service

# 2. Generate Terraform code
terraform show

# 3. Refactor into module
mv generated.tf modules/k8s_app_deployment/main.tf

# 4. Apply with Terraform
terraform apply
```

### From Terraform to YAML

If you start with Terraform and want to move to YAML:

```bash
# 1. Export resources as YAML
kubectl get deployment nestjs-app-deployment -o yaml > deployment.yaml
kubectl get service nestjs-app-service -o yaml > service.yaml
kubectl get ingress nestjs-app-ingress -o yaml > ingress.yaml
kubectl get hpa nestjs-app-hpa -o yaml > hpa.yaml

# 2. Clean up YAML (remove generated fields)
# Edit files to remove: resourceVersion, uid, generation, etc.

# 3. Remove from Terraform state
terraform state rm kubernetes_deployment.app
terraform state rm kubernetes_service.app
terraform state rm kubernetes_ingress_v1.app
terraform state rm kubernetes_horizontal_pod_autoscaler_v2.app

# 4. Manage with kubectl
kubectl apply -f k8s-manifests/
```

## Recommendations

### For This Repository (Learning/Comparison)

Since the goal is to compare ECS vs EKS, I recommend:

**Primary Approach: YAML Manifests** ([k8s-manifests/](k8s-manifests/))
- Demonstrates standard Kubernetes practices
- Easier to explain Kubernetes concepts
- More representative of real-world K8s usage
- Better learning experience

**Secondary Approach: Terraform Module** ([modules/k8s_app_deployment/](modules/k8s_app_deployment/))
- Keep for demonstration purposes
- Shows unified Terraform workflow
- Useful for teams already using Terraform everywhere

### For Production Use

**Small Team (<10 engineers):**
- Use Terraform for everything if team is already Terraform-proficient
- Simpler mental model, unified tooling

**Medium Team (10-50 engineers):**
- Terraform for infrastructure (EKS, VPC, IAM)
- YAML + kubectl for applications
- Consider GitOps (ArgoCD) for application deployment

**Large Team (50+ engineers):**
- Terraform for core infrastructure
- GitOps (ArgoCD/FluxCD) for all applications
- Platform team provides self-service for product teams

## Summary

Both approaches deploy identical Kubernetes resources:

| What | YAML Approach | Terraform Approach |
|------|---------------|-------------------|
| **Files** | [k8s-manifests/](k8s-manifests/) | [modules/k8s_app_deployment/](modules/k8s_app_deployment/) + [deployment/prod/k8s_app/](deployment/prod/k8s_app/) |
| **Tool** | `kubectl` | `terraform` |
| **When** | ⭐ Recommended for most teams | Use if all-Terraform workflow |
| **Why** | Industry standard, GitOps-friendly | Unified tooling, automatic integration |

**Think of it like:** SQL (YAML) vs ORM (Terraform) - same outcome, different developer experience.

---

**Quick Start:**

Choose one approach and follow the deployment steps in [QUICKSTART.md](QUICKSTART.md).

For most users, start with the **YAML approach** and migrate to Terraform later if needed.
