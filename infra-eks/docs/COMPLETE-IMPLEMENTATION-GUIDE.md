# Complete EKS Implementation Guide

This document provides a complete overview of the EKS infrastructure implementation, including all modules, deployment configurations, workflows, and how they integrate with existing ECS infrastructure.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Directory Structure](#directory-structure)
4. [Shared Resources](#shared-resources)
5. [EKS-Specific Resources](#eks-specific-resources)
6. [Deployment Approaches](#deployment-approaches)
7. [GitHub Actions Workflows](#github-actions-workflows)
8. [Deployment Guide](#deployment-guide)
9. [Cost Analysis](#cost-analysis)
10. [Troubleshooting](#troubleshooting)

## Overview

This EKS implementation provides a complete Kubernetes-based alternative to the existing ECS infrastructure. It demonstrates:

- ✅ **Production-ready EKS cluster** with managed node groups
- ✅ **Kubernetes application deployment** (Deployment, Service, Ingress, HPA)
- ✅ **Automated CI/CD pipelines** via GitHub Actions
- ✅ **Resource sharing** with ECS (VPC, ECR, ACM)
- ✅ **Two deployment approaches** (YAML manifests and Terraform)
- ✅ **Comprehensive documentation** and guides

**Key Features:**
- Runs alongside existing ECS infrastructure
- Shares VPC, ECR, and SSL certificates to minimize costs
- Fully automated deployment and destruction workflows
- Cost-optimized with SPOT instances for dev environments
- Production-ready with security best practices

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud                               │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    VPC (Shared)                            │ │
│  │                                                            │ │
│  │  ┌──────────────┐                  ┌──────────────┐        │ │
│  │  │   Public     │                  │   Public     │        │ │
│  │  │  Subnet 1    │                  │  Subnet 2    │        │ │
│  │  │              │                  │              │        │ │
│  │  │  ┌────────┐  │                  │  ┌────────┐  │        │ │
│  │  │  │  ALB   │  │                  │  │  ALB   │  │        │ │
│  │  │  │ (EKS)  │  │                  │  │ (EKS)  │  │        │ │
│  │  │  └────────┘  │                  │  └────────┘  │        │ │
│  │  └──────────────┘                  └──────────────┘        │ │
│  │                                                            │ │
│  │  ┌──────────────┐                  ┌──────────────┐        │ │
│  │  │   Private    │                  │   Private    │        │ │
│  │  │  Subnet 1    │                  │  Subnet 2    │        │ │
│  │  │              │                  │              │        │ │
│  │  │  ┌────────┐  │                  │  ┌────────┐  │        │ │
│  │  │  │  EKS   │  │                  │  │  EKS   │  │        │ │
│  │  │  │  Node  │  │                  │  │  Node  │  │        │ │
│  │  │  │        │  │                  │  │        │  │        │ │
│  │  │  │ [Pods] │  │                  │  │ [Pods] │  │        │ │
│  │  │  └────────┘  │                  │  └────────┘  │        │ │
│  │  └──────────────┘                  └──────────────┘        │ │
│  │                                                            │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌────────────┐   ┌────────────┐   ┌─────────────────────────┐  │
│  │    ECR     │   │    ACM     │   │    EKS Control Plane    │  │
│  │  (Shared)  │   │  (Shared)  │   │     (EKS-Specific)      │  │
│  └────────────┘   └────────────┘   └─────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Component Mapping: ECS → EKS

| ECS Component | EKS Equivalent | Location |
|---------------|----------------|----------|
| **ECS Cluster** | EKS Cluster | [modules/eks_cluster/](modules/eks_cluster/) |
| **EC2 + ASG** | EKS Node Group | [modules/eks_node_group/](modules/eks_node_group/) |
| **Task Definition** | Kubernetes Deployment | [k8s-manifests/deployment.yaml](k8s-manifests/deployment.yaml) |
| **ECS Service** | Kubernetes Service | [k8s-manifests/service.yaml](k8s-manifests/service.yaml) |
| **Target Group + ALB** | Ingress + AWS LB Controller | [k8s-manifests/ingress.yaml](k8s-manifests/ingress.yaml) |
| **Service Auto Scaling** | Horizontal Pod Autoscaler | [k8s-manifests/hpa.yaml](k8s-manifests/hpa.yaml) |
| **Task Role** | Service Account + IRSA | [modules/k8s_app_deployment/main.tf](modules/k8s_app_deployment/main.tf) |

## Directory Structure

```
infra-eks/
├── modules/                                   # Terraform modules
│   ├── eks_cluster/                           # EKS control plane
│   │   ├── main.tf                            # EKS cluster resource
│   │   ├── iam.tf                             # Cluster IAM roles
│   │   ├── security-groups.tf                 # Security groups
│   │   ├── locals.tf                          # Common tags
│   │   ├── vars.tf                            # Input variables
│   │   ├── outputs.tf                         # Module outputs
│   │   └── versions.tf                        # Provider versions
│   │
│   ├── eks_node_group/                        # EKS managed worker nodes
│   │   ├── main.tf                            # Node group + launch template
│   │   ├── iam.tf                             # Node IAM roles
│   │   ├── locals.tf                          # Common tags
│   │   ├── vars.tf                            # Input variables
│   │   ├── outputs.tf                         # Module outputs
│   │   └── versions.tf                        # Provider versions
│   │   # Note: AWS EKS automatically handles node bootstrapping
│   │   # (joining cluster, authentication) for managed node groups
│   │
│   └── k8s_app_deployment/                    # Kubernetes application
│       ├── main.tf                            # Deployment + ServiceAccount
│       ├── service.tf                         # Kubernetes Service
│       ├── ingress.tf                         # Ingress (creates ALB)
│       ├── hpa.tf                             # Horizontal Pod Autoscaler
│       ├── locals.tf                          # Common tags/labels
│       ├── vars.tf                            # Input variables
│       ├── outputs.tf                         # Module outputs
│       └── versions.tf                        # Provider versions
│
├── deployment/prod/                           # Production deployments
│   ├── eks_cluster/                           # EKS cluster deployment
│   │   ├── config.tf                          # Remote state + module call
│   │   ├── vars.tf                            # Deployment variables
│   │   ├── outputs.tf                         # Deployment outputs
│   │   ├── provider.tf                        # AWS provider + tags
│   │   └── backend.tf                         # S3 backend config
│   │
│   ├── eks_node_group/                        # Node group deployment
│   │   ├── config.tf                          # Remote state + module call
│   │   ├── vars.tf                            # Deployment variables
│   │   ├── outputs.tf                         # Deployment outputs
│   │   ├── provider.tf                        # AWS provider + tags
│   │   └── backend.tf                         # S3 backend config
│   │
│   ├── k8s_app/                               # K8s app deployment
│   │   ├── config.tf                          # Remote state + module call
│   │   ├── vars.tf                            # Deployment variables
│   │   ├── outputs.tf                         # Deployment outputs
│   │   ├── provider.tf                        # AWS + K8s providers
│   │   └── backend.tf                         # S3 backend config
│   │
│   └── SHARED-RESOURCES.md                    # Shared resources guide
│
├── k8s-manifests/                             # Raw YAML manifests
│   ├── deployment.yaml                        # Application deployment
│   ├── service.yaml                           # Kubernetes service
│   ├── ingress.yaml                           # ALB Ingress
│   └── hpa.yaml                               # Autoscaler
│
├── scripts/                                   # Helper scripts
│   └── generate-manifests.sh                  # Generate manifests with values
│
├── workflows/                                 # GitHub Actions workflows
│   ├── deploy_eks_infra.yaml                  # Deployment workflow
│   ├── destroy_eks_infra.yaml                 # Destruction workflow
│   └── README.md                              # Workflows documentation
│
├── README.md                                  # Main EKS guide
├── QUICKSTART.md                              # 30-minute deployment guide
├── ECS-vs-EKS-COMPARISON.md                   # ECS vs EKS comparison
├── IMPLEMENTATION-SUMMARY.md                  # Implementation overview
├── DEPLOYMENT-APPROACHES.md                   # YAML vs Terraform guide
└── COMPLETE-IMPLEMENTATION-GUIDE.md           # This file
```

## Shared Resources

These resources are deployed once and used by both ECS and EKS:

### 1. VPC (Virtual Private Cloud)

**Location:** `infra/deployment/prod/vpc/`

**State Key:** `deployment/prod/vpc/terraform.tfstate`

**Resources:**
- VPC with CIDR block
- Public subnets (2 AZs)
- Private subnets (2 AZs)
- Internet Gateway
- NAT Gateways (optional)
- Route tables

**Used By:**
- ECS cluster nodes
- ECS ALB
- EKS cluster (control plane endpoints)
- EKS node groups
- EKS ALB (created by Ingress)

**Cost:** FREE (NAT Gateway charges if enabled)

### 2. ECR (Elastic Container Registry)

**Location:** `infra/deployment/ecr/`

**State Key:** `deployment/ecr/terraform.tfstate`

**Resources:**
- ECR repository for Docker images
- Lifecycle policies
- Image scanning configuration

**Used By:**
- ECS task definitions pull images
- Kubernetes deployments pull images

**Cost:** ~$0.10/GB/month for storage

### 3. ACM Certificate (SSL/TLS)

**Location:** `infra/deployment/ssl/`

**State Key:** `deployment/ssl/terraform.tfstate`

**Resources:**
- ACM certificate
- DNS validation records (Route53)

**Used By:**
- ECS ALB HTTPS listeners
- EKS Ingress HTTPS configuration

**Cost:** FREE

## EKS-Specific Resources

These resources are only used by EKS:

### 1. EKS Cluster (Control Plane)

**Module:** [modules/eks_cluster/](modules/eks_cluster/)

**Deployment:** [deployment/prod/eks_cluster/](deployment/prod/eks_cluster/)

**State Key:** `deployment/prod/eks_cluster/terraform.tfstate`

**Key Resources:**
- EKS cluster (Kubernetes control plane)
- Cluster IAM role
- Cluster security group
- Node security group
- CloudWatch log groups (API, audit, etc.)
- OIDC provider for IRSA

**Configuration:**
- Kubernetes version: 1.32
- Endpoint access: Public + Private
- Encryption: Enabled for secrets
- Logging: All 5 log types enabled

**Cost:** $72/month (fixed cost per cluster)

### 2. EKS Node Group (Worker Nodes)

**Module:** [modules/eks_node_group/](modules/eks_node_group/)

**Deployment:** [deployment/prod/eks_node_group/](deployment/prod/eks_node_group/)

**State Key:** `deployment/prod/eks_node_group/terraform.tfstate`

**Key Resources:**
- Managed node group
- Launch template
- Node IAM role with policies
- Auto Scaling Group (managed by EKS)

**Configuration:**
- Instance type: t3.medium (prod), t3.medium (dev)
- Capacity type: ON_DEMAND (prod), SPOT (dev)
- Desired size: 3 (prod), 2 (dev)
- Min size: 2 (prod), 1 (dev)
- Max size: 10 (prod), 5 (dev)
- Disk size: 50GB (prod), 30GB (dev)

**Cost:** ~$60/month for 2 × t3.medium nodes

### 3. Kubernetes Application

**Module:** [modules/k8s_app_deployment/](modules/k8s_app_deployment/)

**Deployment:** [deployment/prod/k8s_app/](deployment/prod/k8s_app/)

**State Key:** `deployment/prod/k8s_app/terraform.tfstate`

**Key Resources:**
- Deployment (application pods)
- Service (internal load balancing)
- Ingress (ALB creation)
- HPA (auto-scaling)
- ServiceAccount (for IRSA)

**Configuration:**
- Replicas: 3 (prod), 2 (dev)
- CPU request: 250m (prod), 125m (dev)
- Memory request: 512Mi (prod), 256Mi (dev)
- HPA min/max: 3-10 (prod), 2-5 (dev)

**Cost:** ~$16/month for ALB (created by Ingress)

### 4. AWS Load Balancer Controller

**Installation:** Via Helm in deployment workflow

**Not Managed by Terraform:** Installed separately

**Key Resources:**
- Deployment in kube-system namespace
- ServiceAccount with IAM role (IRSA)
- IAM policy for ALB management
- CustomResourceDefinitions (CRDs)

**Purpose:** Automatically creates and manages ALBs from Kubernetes Ingress resources

## Deployment Approaches

This implementation provides **two alternative approaches** for deploying Kubernetes applications:

### Approach 1: Raw YAML Manifests (Recommended)

**Location:** [k8s-manifests/](k8s-manifests/)

**Deployment Tool:** `kubectl`

**Pros:**
- ✅ Industry standard Kubernetes approach
- ✅ GitOps-friendly (ArgoCD, FluxCD)
- ✅ Portable across cloud providers
- ✅ Simple YAML format

**Cons:**
- ⚠️ Manual value substitution needed
- ⚠️ No automatic Terraform integration

**Deployment:**
```bash
# Generate manifests with actual values
./infra-eks/scripts/generate-manifests.sh my-state-bucket eu-west-1

# Deploy to Kubernetes
kubectl apply -f infra-eks/k8s-manifests-generated/
```

### Approach 2: Terraform Kubernetes Provider

**Module:** [modules/k8s_app_deployment/](modules/k8s_app_deployment/)

**Deployment:** [deployment/prod/k8s_app/](deployment/prod/k8s_app/)

**Deployment Tool:** `terraform`

**Pros:**
- ✅ Unified Terraform workflow
- ✅ Automatic remote state integration
- ✅ Type safety and validation
- ✅ Environment-specific variables

**Cons:**
- ⚠️ Less common in K8s-native orgs
- ⚠️ K8s resources in Terraform state
- ⚠️ Not GitOps-friendly

**Deployment:**
```bash
cd infra-eks/deployment/prod/k8s_app
terraform init
terraform apply
```

**See [DEPLOYMENT-APPROACHES.md](DEPLOYMENT-APPROACHES.md) for detailed comparison.**

## GitHub Actions Workflows

### Workflow Files Location

**Important:** Workflow files are provided in `.github/workflows/eks/` for reference. To use them, copy to `.github/workflows/`:

```bash
cp .github/workflows/eks/*.yaml .github/workflows/
```

### deploy_eks_infra.yaml

**Purpose:** Automated EKS infrastructure deployment

**Triggers:**
- Push to `main` with changes in `infra-eks/**`
- Manual workflow dispatch

**Jobs:**
1. **test-eks-terraform-modules** - Run Terraform tests
2. **verify-shared-resources** - Check VPC, ECR, ACM exist
3. **deploy-eks-cluster** - Deploy EKS control plane
4. **deploy-eks-node-group** - Deploy worker nodes
5. **install-aws-load-balancer-controller** - Install ALB controller
6. **deploy-k8s-application** - Deploy application
7. **deployment-summary** - Display results

**Execution Time:** ~30-40 minutes

**Required Secrets:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `TERRAFORM_STATE_BUCKET_NAME`

### destroy_eks_infra.yaml

**Purpose:** Safe EKS infrastructure destruction

**Triggers:**
- Manual workflow dispatch only
- Requires typing "destroy" as confirmation

**Jobs:**
1. **validate-destruction** - Confirm destruction intent
2. **destroy-k8s-application** - Delete K8s resources
3. **uninstall-aws-load-balancer-controller** - Remove controller
4. **destroy-eks-node-group** - Delete worker nodes
5. **destroy-eks-cluster** - Delete control plane
6. **cleanup-orphaned-resources** - Clean up ALBs, SGs, ENIs
7. **destruction-summary** - Display results

**Execution Time:** ~20-30 minutes

**Safety Features:**
- Manual trigger only
- Confirmation required
- Preserves shared resources (VPC, ECR, ACM)
- Cleans up orphaned ALBs before cluster deletion

**See [workflows/README.md](workflows/README.md) for detailed documentation.**

## Deployment Guide

### Prerequisites

1. **Shared Resources Deployed:**
   ```bash
   cd infra/deployment/prod/vpc && terraform apply
   cd ../../ecr && terraform apply
   cd ../ssl && terraform apply
   ```

2. **Required Tools Installed:**
   - Terraform >= 1.7.0
   - kubectl >= 1.32.0
   - AWS CLI configured
   - Helm >= 3.13.0

3. **GitHub Secrets Configured:**
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `TERRAFORM_STATE_BUCKET_NAME`

### Manual Deployment (Step-by-Step)

#### Step 1: Deploy EKS Cluster

```bash
cd infra-eks/deployment/prod/eks_cluster

# Update backend.tf with your S3 bucket name
# Update vars.tf with your configuration

terraform init
terraform plan -var="state_bucket_name=YOUR_BUCKET"
terraform apply -var="state_bucket_name=YOUR_BUCKET"

# Wait ~15 minutes for cluster creation
```

#### Step 2: Deploy EKS Node Group

```bash
cd ../eks_node_group

terraform init
terraform plan -var="state_bucket_name=YOUR_BUCKET"
terraform apply -var="state_bucket_name=YOUR_BUCKET"

# Wait ~10 minutes for nodes to be ready
```

#### Step 3: Configure kubectl

```bash
aws eks update-kubeconfig \
  --name prod-terraform-course-dummy-nestjs-app-eks-cluster \
  --region eu-west-1

kubectl get nodes  # Verify nodes are ready
```

#### Step 4: Install AWS Load Balancer Controller

```bash
# Install CRDs
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

# Add Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=prod-terraform-course-dummy-nestjs-app-eks-cluster \
  --set region=eu-west-1

# Verify installation
kubectl get deployment -n kube-system aws-load-balancer-controller
```

#### Step 5: Deploy Application

**Option A: Using Terraform**
```bash
cd infra-eks/deployment/prod/k8s_app

terraform init
terraform plan -var="state_bucket_name=YOUR_BUCKET"
terraform apply -var="state_bucket_name=YOUR_BUCKET"

# Get application URL
terraform output application_url
```

**Option B: Using kubectl**
```bash
# Generate manifests with actual values
./infra-eks/scripts/generate-manifests.sh YOUR_BUCKET eu-west-1

# Deploy to Kubernetes
kubectl apply -f infra-eks/k8s-manifests-generated/

# Get ALB URL
kubectl get ingress nestjs-app-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

#### Step 6: Verify Deployment

```bash
# Check all resources
kubectl get all

# Specific checks
kubectl get deployments
kubectl get services
kubectl get ingress
kubectl get hpa

# Check pods
kubectl get pods
kubectl logs -f deployment/nestjs-app-deployment

# Test application
curl https://YOUR_ALB_HOSTNAME/health
```

### Automated Deployment (GitHub Actions)

#### Step 1: Copy Workflows

```bash
cp .github/workflows/eks/*.yaml .github/workflows/
```

#### Step 2: Push to GitHub

```bash
git add .github/workflows/
git commit -m "feat: add EKS deployment workflows"
git push origin main
```

#### Step 3: Monitor Workflow

1. Go to GitHub Actions tab
2. Select "Deploy EKS Infrastructure" workflow
3. Monitor progress (~30-40 minutes)

#### Step 4: Get Application URL

Check the "deployment-summary" job output for the application URL.

### Destruction

**Manual:**
```bash
# Destroy in reverse order
cd infra-eks/deployment/prod/k8s_app && terraform destroy
cd ../eks_node_group && terraform destroy
cd ../eks_cluster && terraform destroy
```

**Automated:**
1. Go to GitHub Actions
2. Select "Destroy EKS Infrastructure"
3. Click "Run workflow"
4. Type "destroy" in confirmation
5. Click "Run workflow"

## Cost Analysis

### Monthly Costs

| Component | Cost | Notes |
|-----------|------|-------|
| **EKS Control Plane** | $72 | Fixed per cluster |
| **EC2 Nodes (2 × t3.medium)** | $60 | ON_DEMAND pricing |
| **ALB** | $16 | Created by Ingress |
| **CloudWatch Logs** | $5 | Control plane + application |
| **ECR Storage** | $1 | Shared with ECS |
| **Data Transfer** | $5 | Estimate |
| **Total EKS** | **$159** | |

### Cost Comparison

| Platform | Control Plane | Compute | ALB | Total |
|----------|--------------|---------|-----|-------|
| **ECS** | FREE | $60 | $16 | **$76** |
| **EKS** | $72 | $60 | $16 | **$148** |
| **Difference** | +$72 | $0 | $0 | **+$72** |

### Cost Optimization Strategies

1. **Use SPOT Instances (Dev):**
   - Save ~70% on compute costs
   - Set `capacity_type = "SPOT"` in vars.tf

2. **Right-size Nodes:**
   - Use t3.small for dev: ~$15/month (vs $30)
   - Use t3.large for prod: ~$60/month

3. **Fargate for Serverless:**
   - Pay per pod instead of per node
   - Good for variable workloads

4. **Share Control Plane:**
   - Run multiple apps in one cluster
   - Amortize $72 across services

5. **Scheduled Scaling:**
   - Scale down nodes after hours
   - Use Cluster Autoscaler

6. **Reserved Instances:**
   - 1-year commitment: -40%
   - 3-year commitment: -60%

**Break-even Point:** EKS becomes cost-effective when running 3+ applications (shared control plane).

## Troubleshooting

### Common Issues

#### 1. EKS Cluster Creation Fails

**Symptom:** Terraform apply fails during cluster creation

**Possible Causes:**
- Insufficient IAM permissions
- VPC subnets not available
- Region capacity issues

**Solution:**
```bash
# Check IAM permissions
aws sts get-caller-identity

# Verify VPC subnets exist
cd infra/deployment/prod/vpc
terraform output vpc_private_subnets
terraform output vpc_public_subnets

# Check EKS service quotas
aws service-quotas list-service-quotas \
  --service-code eks \
  --region eu-west-1
```

#### 2. Nodes Not Joining Cluster

**Symptom:** Node group created but nodes not appearing in `kubectl get nodes`

**Possible Causes:**
- Security group misconfiguration blocking cluster communication
- IAM role missing required EKS policies (AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy, AmazonEC2ContainerRegistryReadOnly)
- Launch template configuration issues (note: AWS EKS automatically handles node bootstrapping for managed node groups)

**Solution:**
```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name prod-terraform-course-dummy-nestjs-app-eks-cluster \
  --nodegroup-name NODEGROUP_NAME \
  --region eu-west-1

# Check security groups allow communication
aws ec2 describe-security-groups \
  --group-ids CLUSTER_SG_ID NODE_SG_ID

# Check node IAM role
aws iam get-role --role-name NODE_ROLE_NAME
```

#### 3. AWS Load Balancer Controller Not Installing

**Symptom:** Helm install fails or controller pods crash

**Possible Causes:**
- OIDC provider not configured
- IAM policy missing
- Service account issues

**Solution:**
```bash
# Check OIDC provider
aws eks describe-cluster \
  --name prod-terraform-course-dummy-nestjs-app-eks-cluster \
  --query "cluster.identity.oidc.issuer" \
  --region eu-west-1

# Check IAM policy exists
aws iam get-policy \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy

# Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

#### 4. Ingress Not Creating ALB

**Symptom:** Ingress created but no ALB appears

**Possible Causes:**
- Load Balancer Controller not running
- Ingress class incorrect
- Subnet tags missing

**Solution:**
```bash
# Check controller is running
kubectl get deployment -n kube-system aws-load-balancer-controller

# Check Ingress status
kubectl describe ingress nestjs-app-ingress

# Check Ingress events
kubectl get events --field-selector involvedObject.name=nestjs-app-ingress

# Verify subnet tags
aws ec2 describe-subnets \
  --subnet-ids SUBNET_ID \
  --query 'Subnets[].Tags'
```

#### 5. Pods Stuck in Pending

**Symptom:** Pods not scheduling to nodes

**Possible Causes:**
- Insufficient node capacity
- Resource requests too high
- Node selector mismatch

**Solution:**
```bash
# Check pod events
kubectl describe pod POD_NAME

# Check node resources
kubectl top nodes

# Check pod resource requests
kubectl get pod POD_NAME -o jsonpath='{.spec.containers[*].resources}'

# Scale nodes manually
aws eks update-nodegroup-config \
  --cluster-name CLUSTER_NAME \
  --nodegroup-name NODEGROUP_NAME \
  --scaling-config desiredSize=5
```

#### 6. Application Not Accessible

**Symptom:** ALB created but application returns errors

**Possible Causes:**
- Target health checks failing
- Security group blocking traffic
- Application not listening on correct port

**Solution:**
```bash
# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn TARGET_GROUP_ARN

# Check pod logs
kubectl logs -f deployment/nestjs-app-deployment

# Check service endpoints
kubectl get endpoints nestjs-app-service

# Test pod directly
kubectl port-forward deployment/nestjs-app-deployment 3000:3000
curl http://localhost:3000/health
```

#### 7. Terraform State Lock

**Symptom:** Terraform apply fails with "state locked" error

**Solution:**
```bash
# Wait for other operations to complete
# Or force unlock (use with caution)
terraform force-unlock LOCK_ID
```

#### 8. GitHub Actions Workflow Fails

**Symptom:** Workflow job fails with permission errors

**Possible Causes:**
- AWS credentials invalid
- Secrets not configured
- IAM permissions insufficient

**Solution:**
1. Check GitHub Secrets are set correctly
2. Verify AWS credentials: `aws sts get-caller-identity`
3. Check IAM policy has required permissions
4. Re-run workflow with debug logging:
   ```yaml
   env:
     TF_LOG: DEBUG
   ```

### Debug Commands

```bash
# EKS Cluster
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods --all-namespaces

# Application
kubectl describe deployment nestjs-app-deployment
kubectl logs -f deployment/nestjs-app-deployment
kubectl get events --sort-by='.lastTimestamp'

# Networking
kubectl get svc
kubectl get ingress
kubectl describe ingress nestjs-app-ingress

# Resources
kubectl top nodes
kubectl top pods

# AWS Resources
aws eks list-clusters --region eu-west-1
aws elbv2 describe-load-balancers
aws ec2 describe-security-groups
```

## Additional Resources

### Documentation Files

- [README.md](README.md) - Main EKS infrastructure guide
- [QUICKSTART.md](QUICKSTART.md) - 30-minute deployment guide
- [ECS-vs-EKS-COMPARISON.md](ECS-vs-EKS-COMPARISON.md) - Detailed comparison
- [DEPLOYMENT-APPROACHES.md](DEPLOYMENT-APPROACHES.md) - YAML vs Terraform
- [deployment/prod/SHARED-RESOURCES.md](deployment/prod/SHARED-RESOURCES.md) - Shared resources
- [workflows/README.md](workflows/README.md) - GitHub Actions guide

### External Resources

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform EKS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster)

### Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review GitHub Actions logs
3. Check Terraform state consistency
4. Open an issue in the repository

---

**Implementation Complete!**

This EKS infrastructure is production-ready and fully documented. You can deploy it alongside your existing ECS infrastructure for comparison or migration purposes.

**Last Updated:** 2025-12-06
