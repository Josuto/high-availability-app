# CI/CD Workflows

All infrastructure deployment and teardown is managed through GitHub Actions workflows located in `.github/workflows/ecs/`. These workflows automate Terraform operations in a dependency-aware order.

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Initial Setup (Manual)                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ↓
         ┌──────────────────────────────────────┐
         │ ecs-deploy-hosted-zone.yaml          │
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
         │ ecs-deploy-aws-infra.yaml            │
         │ 1. Test Terraform modules            │
         │ 2. Deploy S3 state bucket            │
         │ 3. Deploy ECR                        │
         │ 4. Retrieve SSL certificate          │
         │ 5. Build and push Docker image       │
         │ 6. Deploy VPC                        │
         │ 7. Deploy ECS cluster                │
         │ 8. Deploy ALB                        │
         │ 9. Deploy ECS service                │
         │ 10. Deploy Route53 routing           │
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
│ ecs-destroy-aws-infra  │        │ ecs-destroy-hosted-    │
│ -yaml                  │        │ zone.yaml              │
│ 1. Destroy ECS service │        │ 1. Destroy hosted zone │
│ 2. Destroy routing     │        │ 2. Destroy S3 bucket   │
│ 3. Destroy ALB         │        │                        │
│ 4. Destroy SSL cert    │        │                        │
│ 5. Destroy ECS cluster │        │                        │
│ 6. Destroy ECR         │        │                        │
│ 7. Destroy VPC         │        │                        │
└────────────────────────┘        └────────────────────────┘
```

---

## 1. Initial Setup

**Workflow**: `ecs-deploy-hosted-zone.yaml`
**Trigger**: Manual (`workflow_dispatch`)
**Purpose**: One-time setup of foundational infrastructure

### Jobs Sequence

1. **deploy-terraform-state-bucket**
   - Creates S3 bucket for Terraform remote state storage
   - Enables versioning for state file history
   - **Reusable Workflow**: Calls `ecs-deploy-terraform-state-bucket.yaml`

2. **deploy-hosted-zone** (depends on: deploy-terraform-state-bucket)
   - Creates Route 53 Hosted Zone for the domain
   - Initializes Terraform with remote state backend
   - Runs `terraform plan` and `terraform apply` in `infra-ecs/deployment/hosted_zone/`
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

**Workflow**: `ecs-deploy-aws-infra.yaml`
**Trigger**: Push to `main` branch
**Purpose**: Complete infrastructure deployment from ECR to running application

### Jobs Sequence

1. **test-terraform-modules**
   - Runs Terraform test suite (`run-tests.sh`)
   - Validates all modules before deployment
   - Uses mock AWS credentials (tests run in plan mode)
   - Working directory: `infra-ecs/`

2. **deploy-terraform-state-bucket** (depends on: test-terraform-modules)
   - Ensures S3 state bucket exists
   - Reusable workflow: `ecs-deploy-terraform-state-bucket.yaml`

3. **deploy-ecr** (depends on: test-terraform-modules, deploy-terraform-state-bucket)
   - Creates ECR repository if it doesn't exist
   - Working directory: `infra-ecs/deployment/ecr/`
   - **Output**: `ecr_repository_name` (used by subsequent jobs)
   - Terraform variables: `common.tfvars`

4. **retrieve-ssl** (depends on: test-terraform-modules, deploy-terraform-state-bucket)
   - Requests ACM certificate for root and wildcard domains
   - Creates DNS validation records in Route 53
   - Waits for certificate validation to complete (can take 5-30 minutes)
   - Working directory: `infra-ecs/deployment/ssl/`
   - Terraform variables: `common.tfvars`, `domain.tfvars`, `backend.tfvars`

5. **build-and-push-app-docker-image-to-ecr** (depends on: deploy-ecr)
   - Sets ECR image tag: `${ECR_REPO_URL}:${ENVIRONMENT}-${GIT_SHA}`
   - Logs in to AWS ECR using `amazon-ecr-login` action
   - Builds NestJS application: `corepack enable`, `pnpm install`, `pnpm build`
   - Builds Docker image: `docker build -t $ECR_APP_IMAGE -f Dockerfile .`
   - Pushes image to ECR: `docker push $ECR_APP_IMAGE`
   - **Tag Format Example**: `123456789012.dkr.ecr.eu-west-1.amazonaws.com/prod-app:prod-a1b2c3d`

6. **deploy-vpc** (depends on: deploy-ecr)
   - Creates VPC, subnets, NAT Gateway(s), Internet Gateway
   - Working directory: `infra-ecs/deployment/app/vpc/`
   - Terraform variables: `common.tfvars`
   - Uses official `terraform-aws-modules/vpc/aws` module

7. **deploy-ecs-cluster** (depends on: deploy-vpc)
   - Creates ECS cluster, Auto Scaling Group, Launch Template, Capacity Provider
   - Creates IAM instance role and instance profile
   - Creates cluster security group
   - Working directory: `infra-ecs/deployment/app/ecs_cluster/`
   - Terraform variables: `common.tfvars`, `backend.tfvars`

8. **deploy-alb** (depends on: retrieve-ssl, deploy-vpc, deploy-ecs-cluster)
   - Creates Application Load Balancer, listeners, target group
   - Attaches validated ACM certificate to HTTPS listener
   - Creates ALB security group
   - Working directory: `infra-ecs/deployment/app/alb/`
   - Terraform variables: `common.tfvars`, `backend.tfvars`

9. **deploy-ecs-service** (depends on: deploy-ecr, build-and-push-app-docker-image-to-ecr, deploy-ecs-cluster, deploy-alb)
   - Creates ECS task definition (with ECR image from step 5)
   - Creates ECS service with load balancer integration
   - Creates task execution role and ECS tasks security group
   - Optionally creates task auto-scaling configuration
   - Working directory: `infra-ecs/deployment/app/ecs_service/`
   - Terraform variables: `common.tfvars`, `backend.tfvars`, `-var="ecr_app_image=$ECR_APP_IMAGE"`

10. **deploy-routing** (depends on: deploy-alb)
    - Creates Route 53 A records (root and www) pointing to ALB
    - Working directory: `infra-ecs/deployment/app/routing/`
    - Terraform variables: `common.tfvars`, `domain.tfvars`, `backend.tfvars`
    - Uses `terraform plan -out=tfplan.binary` for safety

### Workflow Environment Variables

```yaml
env:
  AWS_REGION: eu-west-1
  TERRAFORM_VERSION: 1.10.3
```

### Secrets Required

- `AWS_ACCESS_KEY_ID`: AWS IAM user access key
- `AWS_SECRET_ACCESS_KEY`: AWS IAM user secret key

---

## 3. Infrastructure Teardown

**Workflows**: `ecs-destroy-aws-infra.yaml` and `ecs-destroy-hosted-zone.yaml`
**Trigger**: Manual (`workflow_dispatch`)
**Purpose**: Clean removal of all infrastructure in reverse dependency order

### Workflow 1: ecs-destroy-aws-infra.yaml

Destroys the application and core services.

**Jobs Sequence**:

1. **destroy-ecs-service**
   - Retrieves ECS cluster name and service name from Terraform outputs
   - **Scales ECS service to 0 tasks**: `aws ecs update-service --desired-count 0`
   - **Waits for stability**: `aws ecs wait services-stable` (ensures tasks are drained)
   - Destroys ECS service resources with `terraform destroy`
   - Working directory: `infra-ecs/deployment/app/ecs_service/`
   - **Why Scale First**: Ensures clean shutdown of running containers before destroying infrastructure

2. **destroy-routing** (depends on: destroy-ecs-service)
   - Destroys Route 53 A records
   - Working directory: `infra-ecs/deployment/app/routing/`

3. **destroy-alb** (depends on: destroy-ecs-service)
   - Destroys ALB, listeners, target group, and security group
   - Working directory: `infra-ecs/deployment/app/alb/`

4. **destroy-ecs-cluster** (depends on: destroy-ecs-service, destroy-alb)
   - Destroys ECS cluster, ASG, Launch Template, Capacity Provider
   - Destroys IAM roles and security groups
   - Working directory: `infra-ecs/deployment/app/ecs_cluster/`

5. **destroy-ssl** (depends on: destroy-alb)
   - Destroys ACM certificate and validation records
   - Working directory: `infra-ecs/deployment/ssl/`

6. **destroy-ecr** (depends on: destroy-ecs-service, destroy-alb)
   - **Deletes all Docker images first**: `aws ecr batch-delete-image --image-ids "$(aws ecr list-images ...)"`
   - Destroys ECR repository with `terraform destroy`
   - Working directory: `infra-ecs/deployment/ecr/`
   - **Why Delete Images First**: Terraform cannot destroy a non-empty ECR repository

7. **destroy-vpc** (depends on: destroy-ecs-cluster, destroy-alb, destroy-ssl, destroy-ecr)
   - Destroys VPC, subnets, NAT Gateway(s), Internet Gateway
   - Working directory: `infra-ecs/deployment/app/vpc/`

### Workflow 2: ecs-destroy-hosted-zone.yaml

Destroys foundational DNS and state storage (run after destroy-aws-infra).

**Jobs Sequence**:

1. **destroy-hosted-zone**
   - Destroys Route 53 Hosted Zone
   - Working directory: `infra-ecs/deployment/hosted_zone/`

2. **destroy-terraform-state-bucket** (depends on: destroy-hosted-zone)
   - **Deletes all Terraform state files**: `aws s3 rm s3://${STATE_BUCKET_NAME} --recursive`
   - **Imports state bucket into local state**: `terraform import aws_s3_bucket.terraform_state_bucket ${STATE_BUCKET_NAME}`
   - Destroys S3 bucket with `terraform destroy`
   - Working directory: `infra-ecs/deployment/backend/`
   - **Why Import**: The state bucket's state is stored in the bucket itself, so it must be imported locally before destruction

---

**Return to:** [Main README](../README.md) | [Prerequisites and Setup](PREREQUISITES_AND_SETUP.md) | [AWS Resources Deep Dive](AWS_RESOURCES_DEEP_DIVE.md)
