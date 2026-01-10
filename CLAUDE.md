# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a learning project demonstrating high-availability AWS infrastructure deployment using Terraform and a minimal NestJS application. The project deploys the same application to both **AWS ECS** (Elastic Container Service) and **AWS EKS** (Elastic Kubernetes Service) as two independent, parallel implementations.

## Application Details

A minimal NestJS API serving two endpoints:
- `/` - Returns "Hello World!"
- `/health` - Returns `true`, logs unique instance ID for diagnostics, used by ALB health checks

The app runs on port 3000, uses pnpm as package manager, and generates a unique instance ID on startup using `randomUUID()` from Node's crypto module.

## Essential Commands

### NestJS Application
```bash
# Install dependencies (uses pnpm)
pnpm install

# Development
pnpm start:dev         # Watch mode with auto-reload
pnpm start:debug       # Debug mode with watch

# Testing
pnpm test              # Run unit tests
pnpm test:watch        # Run tests in watch mode
pnpm test:cov          # Generate coverage report
pnpm test:e2e          # Run e2e tests

# Production build
pnpm build             # Compile TypeScript to dist/
pnpm start:prod        # Run compiled app

# Code quality
pnpm format            # Format with Prettier
pnpm lint              # Lint and fix with ESLint
```

### Terraform Infrastructure

**Pre-commit hooks**: Run `pre-commit install` and `pre-commit install --hook-type pre-push` after initial clone. Hooks automatically format Terraform, validate syntax, check security (Trivy), and prevent secret commits.

**Prerequisites for deployment**:
- Owned domain name (for SSL certificate)
- AWS credentials configured
- Required tools: Terraform 1.0+, TFLint, Trivy, detect-secrets, terraform-docs

**Format Terraform before committing**:
```bash
terraform fmt -recursive infra/
```

**ECS Infrastructure** (in `infra-ecs/`):
```bash
# Navigate to specific deployment stage
cd infra-ecs/deployment/<stage>

# Examples:
cd infra-ecs/deployment/prod/vpc
cd infra-ecs/deployment/ssl

# Standard Terraform workflow
terraform init
terraform plan -var-file=../../common.tfvars
terraform apply -var-file=../../common.tfvars
terraform destroy -var-file=../../common.tfvars
```

**EKS Infrastructure** (in `infra-eks/`):
```bash
# Similar structure to ECS
cd infra-eks/deployment/<stage>
terraform init
terraform plan -var-file=../../common.tfvars
terraform apply -var-file=../../common.tfvars
```

**Run TFLint locally**:
```bash
cd infra-ecs/  # or infra-eks/
tflint --init
tflint --recursive
```

## Architecture Overview

### Dual Implementation Structure

This repository maintains two complete, independent infrastructure implementations:

1. **ECS Implementation** (`infra-ecs/`): AWS-native container orchestration
2. **EKS Implementation** (`infra-eks/`): Kubernetes-based container orchestration

Both implementations:
- Share the same NestJS application code
- Use separate Terraform state files (`deployment/` vs `deployment-eks/`)
- Have independent CI/CD workflows
- Can run simultaneously without conflicts
- Deploy to the same AWS account but use isolated resources

### Terraform Module Architecture

The infrastructure follows a strict separation between **Root Modules** (deployment stages) and **Child Modules** (reusable components):

**Child Modules** (`infra-*/modules/*`):
- Single-purpose, reusable infrastructure components
- Examples: `ecr`, `alb`, `ecs_cluster`, `ecs_service`, `ssl`, `hosted_zone`, `routing`
- Accept inputs via variables, return outputs
- No knowledge of other modules or deployment stages
- Designed for maximum reusability across projects

**Root Modules** (`infra-*/deployment/*`):
- Environment-specific orchestration (e.g., `prod/vpc`, `prod/ecs_service`)
- Stitch child modules together using outputs from previous stages
- Use `data "terraform_remote_state"` to read outputs from other stages
- Pass environment-specific configuration to child modules

**Deployment Stages**: Infrastructure is deployed in dependency order:
1. `backend/` - S3 bucket for Terraform remote state
2. `hosted_zone/` - Route53 hosted zone (requires manual DNS propagation)
3. `ssl/` - ACM certificate (depends on Route53)
4. `ecr/` - Docker registry
5. `prod/vpc/` - Network infrastructure
6. `prod/ecs_cluster/` or `prod/eks_cluster/` - Compute cluster
7. `prod/alb/` - Application Load Balancer
8. `prod/ecs_service/` or `prod/app/` - Application deployment
9. `prod/routing/` - Route53 DNS records pointing to ALB

### ECS Architecture Components

- **VPC**: Isolated network with public/private subnets across multiple AZs
- **ECR**: Private Docker registry with lifecycle policies (aggressive cleanup of untagged, retention of env-tagged images)
- **ECS Cluster**: EC2-based with Auto Scaling Group, Capacity Provider, and ECS Agent
- **ECS Service**: Manages task count, integrates with ALB Target Group
- **ECS Task**: Container running on EC2 with `awsvpc` networking, registered with ALB
- **ALB**: Port 443 (HTTPS) listener, redirects Port 80 to HTTPS (301), distributes to Target Group
- **Route 53 + ACM**: DNS management and SSL certificate validation

**Security Model**:
- **IAM Roles**:
  - `ecs_instance_role`: EC2 instances (join cluster, pull images, logging, SSM access)
  - `ecs_task_execution_role`: ECS service (pull images, write logs)
- **Security Groups**:
  - `alb-sg`: Ingress 80/443 from internet, egress all
  - `ecs-tasks-sg`: Ingress port 3000 from ALB only, egress all
  - `cluster-sg`: Egress all (for EC2 instances)

### EKS Architecture Components

See `infra-eks/` directory for complete EKS documentation, including:
- `GETTING-STARTED.md` - Introduction to EKS implementation
- `QUICKSTART.md` - Step-by-step deployment guide
- `ECS-vs-EKS-COMPARISON.md` - Detailed comparison of both approaches
- Additional guides for production operations, troubleshooting, and cost optimization

### Environment Configuration

Configuration differences between `dev` and `prod` (defined in `infra-*/deployment/common.tfvars`):

| Setting | dev | prod | Rationale |
|---------|-----|------|-----------|
| NAT Gateway | Single | Multiple | Cost vs HA |
| ECR Image Retention | 3 tagged | 10 tagged | Storage vs rollback depth |
| ASG Min/Max | 1/2 | 2/4 | Cost vs capacity |
| ECS Max Utilization | 100% | 75% | Cost vs scaling buffer |
| Scale-In Protection | false | true | Quick teardown vs stability |
| Task Placement | binpack:cpu | spread:az,instanceId | Cost vs fault tolerance |
| ALB Deletion Protection | false | true | Flexibility vs safety |
| Route53 force_destroy | true | false | Cleanup vs domain protection |

## CI/CD Workflows

**GitHub Actions** workflows automate infrastructure deployment and teardown. All workflows are manually triggered via `workflow_dispatch`.

### ECS Workflows (`.github/workflows/ecs/`)
- `ecs-deploy-hosted-zone.yaml` - Creates S3 state bucket and Route53 zone
- `ecs-deploy-aws-infra.yaml` - Full infrastructure deployment (ECR → SSL → Build image → VPC → Cluster → ALB → Service → Routing)
- `ecs-destroy-aws-infra.yaml` - Destroys application infrastructure (Service → Routing → ALB → SSL → Cluster → ECR → VPC)
- `ecs-destroy-hosted-zone.yaml` - Destroys Route53 zone and S3 state bucket

### EKS Workflows (`.github/workflows/`)
- `eks_deploy_terraform_state_bucket.yaml` - Creates S3 state bucket
- `eks_deploy_hosted_zone.yaml` - Creates Route53 zone
- `eks_deploy_aws_infra.yaml` - Full EKS infrastructure deployment
- `eks_destroy_aws_infra.yaml` - Destroys EKS infrastructure
- `eks_destroy_hosted_zone.yaml` - Destroys Route53 zone and state bucket

**Critical Deployment Requirements**:
1. You must own a domain name
2. After deploying hosted zone, manually update DNS nameservers at your domain registrar
3. Wait for DNS propagation before deploying SSL certificate
4. Workflows are manually triggered (not automatic on push)

### Workflow Dependencies
Deployment order must be strictly followed due to dependencies between stages. The workflows use job dependencies to enforce correct order. Terraform remote state files enable stages to reference outputs from previous stages.

## Project Limitations

**No Terraform State Locking**: The project does not implement DynamoDB state locking. This is acceptable for:
- Single developer environments
- Learning/experimentation

For team collaboration, state locking is critical to prevent:
- State file corruption from concurrent operations
- Race conditions between multiple terraform applies
- Lost updates when developers work simultaneously

To enable locking, uncomment `dynamodb_table` parameter in `backend.tf` files and create a DynamoDB table with `LockID` as primary key.

## Code References

When discussing code, use the format `file_path:line_number` to reference specific locations. Examples:
- Application bootstraps in `src/main.ts:6`
- Instance ID generated in `src/app.module.ts:14`
- ECS module configuration in `infra-ecs/modules/ecs_service/`

## Important Notes

- All AWS resources are tagged with `Project = high-availability-app` for easy identification
- The NestJS app uses a unique instance ID for load balancer health check diagnostics
- Docker images are tagged with `${environment}-${git-sha}` format in CI/CD
- Pre-commit hooks will auto-format Terraform files - stage the changes and commit again if rejected
- ECS and EKS implementations can run in parallel for comparison/testing
- Always check `infra-eks/` documentation when working with Kubernetes deployment
