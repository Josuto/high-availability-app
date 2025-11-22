# Deployment Configuration

This directory contains the Terraform configuration for deploying the infrastructure across different environments.

## Configuration Files

### backend-config.hcl

Contains the S3 backend configuration for Terraform state management. This file must be updated with your own values before deployment.

**IMPORTANT**: Update the `bucket` value with your own S3 bucket name.

### Variable Files

Variables are organized into three separate files based on their scope and usage:

#### common.tfvars
Contains variables used across **all modules** for resource naming and tagging:
- `project_name` - Project identifier used for resource tagging and naming
- `environment` - Environment identifier (dev, prod)

#### backend.tfvars
Contains variables used by **modules that reference remote Terraform state**:
- `state_bucket_name` - S3 bucket name for Terraform state storage (must be globally unique)

#### domain.tfvars
Contains variables used by **SSL and DNS-related modules**:
- `root_domain` - Your registered root domain name (must match your Route53 hosted zone)

## Required Variables

Before deploying, you must configure the following variables in their respective files:

| Variable | File | Description | Example Value |
|----------|------|-------------|---------------|
| `project_name` | `common.tfvars` | Project identifier used for resource tagging and naming. | `high-availability-app` |
| `environment` | `common.tfvars` | Environment identifier (dev, prod). | `dev` |
| `state_bucket_name` | `backend.tfvars` | S3 bucket name for Terraform state storage. Must be globally unique. | `your-company-terraform-state-bucket` |
| `root_domain` | `domain.tfvars` | Your registered root domain name. Must match your Route53 hosted zone. | `example.com` |

## Usage

### Initializing Terraform

When initializing Terraform in any deployment directory, you must pass the backend configuration file:

```bash
# From a deployment subdirectory (e.g., infra/deployment/prod/vpc/)
terraform init -backend-config="../../backend-config.hcl"

# From a deployment directory (e.g., infra/deployment/ssl/)
terraform init -backend-config="../backend-config.hcl"
```

### Planning and Applying Changes

When running `terraform plan` or `terraform apply`, you must provide the required variable files. Each module requires different combinations of tfvars files depending on its dependencies:

#### Variable File Usage by Module

| Module | Required tfvars Files |
|--------|----------------------|
| **backend** | `common.tfvars` + `backend.tfvars` |
| **hosted_zone** | `common.tfvars` + `domain.tfvars` + `backend.tfvars` |
| **ecr** | `common.tfvars` |
| **ssl** | `common.tfvars` + `domain.tfvars` + `backend.tfvars` |
| **prod/vpc** | `common.tfvars` + `backend.tfvars` |
| **prod/ecs_cluster** | `common.tfvars` + `backend.tfvars` |
| **prod/alb** | `common.tfvars` + `backend.tfvars` |
| **prod/ecs_service** | `common.tfvars` + `backend.tfvars` |
| **prod/routing** | `common.tfvars` + `domain.tfvars` + `backend.tfvars` |

#### Examples

1. **ECR (simple - only common variables)**:
   ```bash
   # From infra/deployment/ecr/
   terraform plan -var-file="../common.tfvars"
   terraform apply -var-file="../common.tfvars" -auto-approve
   ```

2. **VPC (common + backend for state references)**:
   ```bash
   # From infra/deployment/prod/vpc/
   terraform plan -var-file="../../common.tfvars" -var-file="../../backend.tfvars"
   terraform apply -var-file="../../common.tfvars" -var-file="../../backend.tfvars" -auto-approve
   ```

3. **SSL (common + domain + backend)**:
   ```bash
   # From infra/deployment/ssl/
   terraform plan -var-file="../common.tfvars" -var-file="../domain.tfvars" -var-file="../backend.tfvars"
   terraform apply -var-file="../common.tfvars" -var-file="../domain.tfvars" -var-file="../backend.tfvars" -auto-approve
   ```

#### Alternative: Pass Variables Individually

You can also pass variables individually (useful for overrides or CI/CD with dynamic values):
```bash
terraform plan \
  -var="project_name=your-project" \
  -var="environment=dev" \
  -var="state_bucket_name=your-bucket-name"
```

**Why we use separate tfvars files:**
- **No undeclared variable warnings**: Each module only receives the variables it actually uses
- **Clear separation of concerns**: Common, backend, and domain variables are logically separated
- **Better maintainability**: Easy to see which modules need which variables
- **Improved documentation**: Each tfvars file has clear comments explaining its purpose

## Directory Structure

```
deployment/
├── backend-config.hcl          # Backend configuration (bucket name)
├── common.tfvars               # Common variables (project_name, environment)
├── backend.tfvars              # Backend variables (state_bucket_name)
├── domain.tfvars               # Domain variables (root_domain)
├── README.md                   # This file
├── backend/                    # Terraform state S3 bucket
├── hosted_zone/                # Route53 hosted zone
├── ecr/                        # ECR repository
├── ssl/                        # SSL certificate
└── prod/                       # Production environment
    ├── vpc/                    # VPC and networking
    ├── ecs_cluster/            # ECS cluster
    ├── alb/                    # Application Load Balancer
    ├── ecs_service/            # ECS service and tasks
    └── routing/                # Route53 DNS records
```

## Deployment Order

The infrastructure must be deployed in the following order:

1. **Backend** - S3 bucket for Terraform state
2. **Hosted Zone** - Route53 hosted zone for your domain
3. **ECR** - Container registry
4. **SSL** - SSL certificate (requires DNS propagation)
5. **VPC** - Virtual Private Cloud and networking
6. **ECS Cluster** - Container compute capacity
7. **ALB** - Application Load Balancer
8. **ECS Service** - Application deployment
9. **Routing** - DNS records pointing to ALB

## First-Time Setup

For new users deploying this infrastructure:

1. Update `backend-config.hcl` with your S3 bucket name
2. Update the variable files with your values:
   - `common.tfvars`: Set your `project_name` and `environment`
   - `backend.tfvars`: Set your `state_bucket_name`
   - `domain.tfvars`: Set your `root_domain`
3. Deploy the backend:
   ```bash
   cd backend
   terraform init
   terraform apply -var-file="../common.tfvars" -var-file="../backend.tfvars"
   ```
4. Deploy the hosted zone:
   ```bash
   cd ../hosted_zone
   terraform init -backend-config="../backend-config.hcl"
   terraform apply -var-file="../common.tfvars" -var-file="../domain.tfvars" -var-file="../backend.tfvars"
   ```
5. Update your domain's nameservers to point to the Route53 hosted zone
6. Wait for DNS propagation (can take up to 48 hours)
7. Continue with the remaining infrastructure deployments

## GitHub Actions

The `.github/workflows/` directory contains CI/CD workflows that automatically handle the deployment order and variable passing. The workflows read configuration values from the variable files in this directory.

To use the workflows in your forked repository:

1. Update the variable files with your own values:
   - `common.tfvars`: Your `project_name` and `environment`
   - `backend.tfvars`: Your `state_bucket_name`
   - `domain.tfvars`: Your `root_domain`
2. Add your AWS credentials as GitHub secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

The workflows will automatically use the appropriate combination of tfvars files for each module, ensuring no undeclared variable warnings occur.
