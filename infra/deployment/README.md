# Deployment Configuration

This directory contains the Terraform configuration for deploying the infrastructure across different environments.

## Configuration Files

### backend-config.hcl

Contains the S3 backend configuration for Terraform state management. This file must be updated with your own values before deployment.

**IMPORTANT**: Update the `bucket` value with your own S3 bucket name.

### terraform.tfvars

Contains common variables used across all deployment configurations. These values must be customized for your deployment.

## Required Variables

Before deploying, you must configure the following variables in `terraform.tfvars`:

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `state_bucket_name` | S3 bucket name for Terraform state storage. Must be globally unique. | `your-company-terraform-state-bucket` |
| `root_domain` | Your registered root domain name. Must match your Route53 hosted zone. | `example.com` |
| `project_name` | Project identifier used for resource tagging and naming. | `high-availability-app` |
| `environment` | Environment identifier (dev, prod). | `dev` |

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

When running `terraform plan` or `terraform apply`, you must provide the required variables. You can either:

1. **Use the tfvars file** (recommended):
   ```bash
   # From a deployment subdirectory (e.g., infra/deployment/prod/vpc/)
   terraform plan -var-file="../../terraform.tfvars"
   terraform apply -var-file="../../terraform.tfvars"

   # From a deployment directory (e.g., infra/deployment/ssl/)
   terraform plan -var-file="../terraform.tfvars"
   terraform apply -var-file="../terraform.tfvars"
   ```

   **Why we recommend this approach:**
   - **Single source of truth**: All configuration values are defined in one central file
   - **Consistency**: Ensures the same values are used across all deployments
   - **Easier maintenance**: Update values in one place instead of multiple workflow files
   - **Less error-prone**: Reduces the risk of typos or inconsistent values across commands
   - **Better for CI/CD**: GitHub Actions workflows automatically read from this file

2. **Pass variables individually**:
   ```bash
   terraform plan \
     -var="state_bucket_name=your-bucket-name" \
     -var="root_domain=example.com" \
     -var="project_name=your-project"
   ```

   This approach is useful for overriding specific values temporarily or for dynamic values that change per execution.

## Directory Structure

```
deployment/
├── backend-config.hcl          # Backend configuration (bucket name)
├── terraform.tfvars            # Common variable values
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
2. Update `terraform.tfvars` with your domain and project name
3. Deploy the backend: `cd backend && terraform init && terraform apply`
4. Deploy the hosted zone: `cd hosted_zone && terraform init -backend-config="../backend-config.hcl" && terraform apply -var-file="../terraform.tfvars"`
5. Update your domain's nameservers to point to the Route53 hosted zone
6. Wait for DNS propagation (can take up to 48 hours)
7. Continue with the remaining infrastructure deployments

## GitHub Actions

The `.github/workflows/` directory contains CI/CD workflows that automatically handle the deployment order and variable passing. The workflows read configuration values from the `terraform.tfvars` file in this directory.

To use the workflows in your forked repository:

1. Update the `terraform.tfvars` file with your own values (bucket name, domain, project name)
2. Add your AWS credentials as GitHub secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

The workflows will automatically use the values from `terraform.tfvars` when running Terraform commands.
