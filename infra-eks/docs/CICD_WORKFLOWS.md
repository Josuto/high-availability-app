# CI/CD Workflows

All infrastructure deployment and teardown is managed through GitHub Actions workflows located in `.github/workflows/eks/`. These workflows automate Terraform operations in a dependency-aware order.

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Initial Setup (Manual)                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ↓
         ┌──────────────────────────────────────┐
         │ eks-deploy-hosted-zone.yaml          │
         │ 1. Deploy S3 state bucket            │
         │ 2. Deploy Route53 Hosted Zone        │
         │ 3. [MANUAL] Update DNS nameservers   │
         │ 4. [MANUAL] Wait for DNS propagation │
         └──────────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│               Full Deployment (On Push to main)             │
└─────────────────────────────────────────────────────────────┘
                            │
                            ↓
         ┌──────────────────────────────────────┐
         │ eks-deploy-aws-infra.yaml            │
         │ 1. Test Terraform modules            │
         │ 2. Deploy S3 state bucket            │
         │ 3. Deploy ECR                        │
         │ 4. Retrieve SSL certificate          │
         │ 5. Build and push Docker image       │
         │ 6. Deploy VPC                        │
         │ 7. Deploy EKS cluster                │
         │ 8. Deploy EKS node group             │
         │ 9. Install AWS LB Controller         │
         │ 10. Deploy K8s application           │
         │ 11. Deploy Route53 routing           │
         └──────────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  Teardown (Manual Trigger)                  │
└─────────────────────────────────────────────────────────────┘
                            │
         ┌──────────────────┴─────────────────────┐
         │                                        │
         ↓                                        ↓
┌────────────────────────┐        ┌────────────────────────┐
│ eks-destroy-aws-infra  │        │ eks-destroy-hosted-    │
│ .yaml                  │        │ zone.yaml              │
│ 1. Destroy routing     │        │ 1. Destroy hosted zone │
│ 2. Destroy K8s app     │        │ 2. Destroy S3 bucket   │
│ 3. Uninstall LB ctrl   │        │                        │
│ 4. Destroy node group  │        │                        │
│ 5. Destroy EKS cluster │        │                        │
│ 6. Destroy SSL cert    │        │                        │
│ 7. Destroy ECR         │        │                        │
│ 8. Destroy VPC         │        │                        │
└────────────────────────┘        └────────────────────────┘
```

---

## 1. Initial Setup

**Workflow**: `eks-deploy-hosted-zone.yaml`
**Trigger**: Manual (`workflow_dispatch`)
**Purpose**: One-time setup of foundational infrastructure

### Jobs Sequence

1. **deploy-terraform-state-bucket**
   - Creates S3 bucket for Terraform remote state storage
   - Enables versioning for state file history
   - **Reusable Workflow**: Calls `eks_deploy_terraform_state_bucket.yaml`

2. **deploy-hosted-zone** (depends on: deploy-terraform-state-bucket)
   - Creates Route 53 Hosted Zone for the domain
   - Initializes Terraform with remote state backend
   - Runs `terraform plan` and `terraform apply` in `infra-eks/deployment/hosted_zone/`
   - **Required Variables**: `common.tfvars` (project_name, environment), `domain.tfvars` (root_domain_name)

### Manual Steps Required After Workflow

1. **Navigate to AWS Console** → Route 53 → Hosted Zones
2. **Copy the nameserver (NS) records** (4 values like `ns-123.awsdns-45.com`)
3. **Update DNS at your domain registrar** with the Route 53 nameservers
4. **Wait for DNS propagation** (can take 5 minutes to 48 hours, typically < 1 hour)
5. **Verify propagation**: Run `dig NS yourdomain.com` or use online DNS checkers

**Why This Matters**: The SSL certificate validation in the next workflow requires functioning DNS. If DNS hasn't propagated, the certificate validation will fail.

---

## 2. Full Infrastructure Deployment

**Workflow**: `eks-deploy-aws-infra.yaml`
**Trigger**: Push to `main` branch
**Purpose**: Complete infrastructure deployment from ECR to running Kubernetes application

### Jobs Sequence

1. **test-eks-terraform-modules**
   - Runs Terraform test suite (`run-tests.sh`)
   - Validates all modules before deployment
   - Uses mock AWS credentials (tests run in plan mode)
   - Working directory: `infra-eks/`

2. **deploy-terraform-state-bucket** (depends on: test-eks-terraform-modules)
   - Ensures S3 state bucket exists
   - Reusable workflow: `eks_deploy_terraform_state_bucket.yaml`

3. **deploy-ecr** (depends on: test-eks-terraform-modules, deploy-terraform-state-bucket)
   - Creates ECR repository if it doesn't exist
   - Working directory: `infra-eks/deployment/ecr/`
   - **Output**: `ecr_repository_name` (used by subsequent jobs)
   - Terraform variables: `common.tfvars`

4. **retrieve-ssl** (depends on: test-eks-terraform-modules, deploy-terraform-state-bucket)
   - Requests ACM certificate for root and wildcard domains
   - Creates DNS validation records in Route 53
   - Waits for certificate validation to complete (can take 5-30 minutes)
   - Working directory: `infra-eks/deployment/ssl/`
   - Terraform variables: `common.tfvars`, `domain.tfvars`, `backend.tfvars`

5. **build-and-push-app-docker-image-to-ecr** (depends on: deploy-ecr)
   - Sets ECR image tag: `${ECR_REPO_URL}:${ENVIRONMENT}-${GIT_SHA}`
   - Logs in to AWS ECR using `amazon-ecr-login` action
   - Builds NestJS application: `corepack enable`, `pnpm install`, `pnpm build`
   - Builds Docker image: `docker build -t $ECR_APP_IMAGE -f Dockerfile .`
   - Pushes image to ECR: `docker push $ECR_APP_IMAGE`
   - **Output**: `image_tag` (used by K8s deployment)

6. **deploy-vpc** (depends on: deploy-ecr)
   - Creates VPC, subnets, NAT Gateway(s), Internet Gateway
   - Applies EKS-specific subnet tags for Load Balancer Controller
   - Working directory: `infra-eks/deployment/app/vpc/`
   - Terraform variables: `common.tfvars`
   - Uses official `terraform-aws-modules/vpc/aws` module

7. **deploy-eks-cluster** (depends on: deploy-vpc)
   - Creates EKS cluster (managed control plane)
   - Creates cluster IAM role and OIDC provider
   - Creates cluster security group
   - Working directory: `infra-eks/deployment/app/eks_cluster/`
   - Terraform variables: `common.tfvars`, `backend.tfvars`
   - **Output**: `cluster_id` (used by subsequent jobs)

8. **deploy-eks-node-group** (depends on: deploy-eks-cluster)
   - Creates managed node group with Auto Scaling
   - Creates node IAM role and instance profile
   - Working directory: `infra-eks/deployment/app/eks_node_group/`
   - Terraform variables: `common.tfvars`, `backend.tfvars`
   - **Waits for nodes to be active**: `aws eks wait nodegroup-active`

9. **install-aws-load-balancer-controller** (depends on: deploy-eks-cluster, deploy-eks-node-group)
   - Installs AWS Load Balancer Controller via Terraform (Helm provider)
   - Creates IAM role with IRSA for controller
   - Working directory: `infra-eks/deployment/app/aws_lb_controller/`
   - Terraform variables: `common.tfvars`, `backend.tfvars`

10. **deploy-k8s-application** (depends on: deploy-ecr, retrieve-ssl, build-and-push-app-docker-image-to-ecr, deploy-eks-cluster, deploy-eks-node-group, install-aws-load-balancer-controller)
    - Configures kubectl to access EKS cluster
    - Creates runtime tfvars with image tag from build job
    - Deploys Kubernetes resources: Deployment, Service, Ingress, HPA
    - Working directory: `infra-eks/deployment/app/k8s_app/`
    - Terraform variables: `common.tfvars`, `domain.tfvars`, `backend.tfvars`, `runtime.auto.tfvars`
    - **Waits for Ingress to provision ALB** (can take 5-10 minutes)
    - **Outputs application URL** for verification

11. **deploy-routing** (depends on: deploy-eks-cluster, install-aws-load-balancer-controller, deploy-k8s-application)
    - Waits for ALB to be fully provisioned
    - Creates Route 53 A record pointing to ALB (created by Ingress)
    - Working directory: `infra-eks/deployment/app/routing/`
    - Terraform variables: `common.tfvars`, `domain.tfvars`, `backend.tfvars`

### Workflow Environment Variables

```yaml
env:
  AWS_REGION: eu-west-1
  TERRAFORM_VERSION: 1.10.3
  KUBECTL_VERSION: 1.28.0
  HELM_VERSION: 3.13.0
```

### Secrets Required

- `AWS_ACCESS_KEY_ID`: AWS IAM user access key
- `AWS_SECRET_ACCESS_KEY`: AWS IAM user secret key

---

## 3. Infrastructure Teardown

**Workflows**: `eks-destroy-aws-infra.yaml` and `eks-destroy-hosted-zone.yaml`
**Trigger**: Manual (`workflow_dispatch`)
**Purpose**: Clean removal of all infrastructure in reverse dependency order

### Workflow 1: eks-destroy-aws-infra.yaml

Destroys the application and core services.

**Jobs Sequence**:

1. **destroy-routing**
   - Destroys Route 53 A records
   - Working directory: `infra-eks/deployment/app/routing/`

2. **destroy-k8s-application** (depends on: destroy-routing)
   - Configures kubectl to access EKS cluster
   - **Manually deletes Ingress resources**: Ensures ALBs are cleaned up
   - Destroys Kubernetes resources with `terraform destroy`
   - Working directory: `infra-eks/deployment/app/k8s_app/`
   - **Why Delete Ingress Manually**: Ensures AWS Load Balancer Controller cleans up ALBs before Terraform destroy

3. **uninstall-aws-load-balancer-controller** (depends on: destroy-k8s-application)
   - Uninstalls Helm chart via Terraform
   - Destroys controller IAM role
   - Working directory: `infra-eks/deployment/app/aws_lb_controller/`

4. **destroy-eks-node-group** (depends on: uninstall-aws-load-balancer-controller)
   - Destroys managed node group
   - Destroys node IAM role
   - Working directory: `infra-eks/deployment/app/eks_node_group/`

5. **destroy-eks-cluster** (depends on: destroy-eks-node-group)
   - **Manually deletes OIDC provider** if it exists
   - Destroys EKS cluster
   - Destroys cluster IAM role and security group
   - Working directory: `infra-eks/deployment/app/eks_cluster/`

6. **cleanup-orphaned-resources** (depends on: destroy-eks-cluster)
   - Checks for orphaned ALBs, security groups, and ENIs
   - Provides warnings if orphaned resources are found
   - **Why**: Sometimes ALBs or security groups aren't fully cleaned up by the controller

7. **destroy-ssl** (depends on: destroy-eks-cluster)
   - Destroys ACM certificate and validation records
   - Working directory: `infra-eks/deployment/ssl/`

8. **destroy-ecr** (depends on: destroy-eks-cluster)
   - **Deletes all Docker images first**: `aws ecr batch-delete-image`
   - Destroys ECR repository with `terraform destroy`
   - Working directory: `infra-eks/deployment/ecr/`

9. **destroy-vpc** (depends on: destroy-ssl, destroy-ecr, cleanup-orphaned-resources)
   - Destroys VPC, subnets, NAT Gateway(s), Internet Gateway
   - Working directory: `infra-eks/deployment/app/vpc/`

### Workflow 2: eks-destroy-hosted-zone.yaml

Destroys foundational DNS and state storage (run after destroy-aws-infra).

**Jobs Sequence**:

1. **destroy-hosted-zone**
   - Destroys Route 53 Hosted Zone
   - Working directory: `infra-eks/deployment/hosted_zone/`

2. **destroy-terraform-state-bucket** (depends on: destroy-hosted-zone)
   - **Deletes all Terraform state files**: `aws s3 rm s3://${STATE_BUCKET_NAME} --recursive`
   - **Imports state bucket into local state**: `terraform import`
   - Destroys S3 bucket with `terraform destroy`
   - Working directory: `infra-eks/deployment/backend/`

---

**Return to:** [Main README](../README.md) | [Prerequisites and Setup](PREREQUISITES_AND_SETUP.md) | [AWS Resources Deep Dive](AWS_RESOURCES_DEEP_DIVE.md)
