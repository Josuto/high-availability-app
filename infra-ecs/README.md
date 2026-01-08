# ECS Infrastructure Documentation

This directory contains the complete Terraform infrastructure for deploying a high-availability NestJS application using AWS Elastic Container Service (ECS). The implementation follows Infrastructure as Code (IaC) principles with modular, reusable components.

## Documentation Index

| Document | Description |
|----------|-------------|
| **[Prerequisites and Setup](docs/PREREQUISITES_AND_SETUP.md)** | Complete guide for first-time configuration, AWS credentials setup, and domain configuration |
| **[AWS Resources Deep Dive](docs/AWS_RESOURCES_DEEP_DIVE.md)** | In-depth technical documentation of all AWS resources, module architecture, IAM policies, and security groups |
| **[CI/CD Workflows](docs/CICD_WORKFLOWS.md)** | GitHub Actions workflows for automated deployment and teardown |
| **[Terraform Testing](docs/TERRAFORM_TESTING.md)** | Testing framework, troubleshooting guide, and detailed test suite documentation |
| **[Security Decisions](docs/SECURITY_DECISIONS.md)** | Security architecture decisions, threat model, and compliance considerations |

---

## Before You Begin

**Required Setup:** Before deploying this infrastructure, you must configure several variables and files with your own values. See the **[Prerequisites and Setup Guide](docs/PREREQUISITES_AND_SETUP.md)** for:
- AWS account and domain requirements
- S3 backend configuration
- Project name and environment setup
- GitHub secrets for CI/CD
- DNS configuration steps

---

## Table of Contents

1. [High-Level Overview](#1-high-level-overview)
   - [1.1. Key Components and Their Relationships](#11-key-components-and-their-relationships)
   - [1.2. Traffic Flow](#12-traffic-flow)
   - [1.3. Core Design Principles](#13-core-design-principles)
   - [1.4. High-Level Architecture](#14-high-level-architecture)
2. [Key Components](#2-key-components)
3. [Environment Configuration Differences](#3-environment-configuration-differences)
4. [CI/CD Workflows](#4-cicd-workflows)
5. [Terraform Testing](#5-terraform-testing)
6. [Project Structure](#6-project-structure)

---

## 1. High-Level Overview

The ECS infrastructure implements a production-ready, highly available container orchestration platform on AWS. The architecture leverages AWS-native services to provide automated scaling, load balancing, and secure HTTPS communication.

### 1.1. Key Components and Their Relationships

```
Internet
    ↓
[Route 53] → Points to ALB DNS
    ↓
[Application Load Balancer (ALB)]
    ↓ (HTTPS:443 / HTTP:80→HTTPS)
[ALB Target Group] ← Health checks ECS Tasks
    ↓
[ECS Tasks] (in awsvpc mode)
    ↓ Running on
[EC2 Instances] (in private VPC subnets)
    ↓ Managed by
[Auto Scaling Group + Capacity Provider]
    ↓ Part of
[ECS Cluster]
```

### 1.2. Traffic Flow

1. **Inbound Traffic**: User requests hit Route 53 → ALB (validates SSL certificate) → Target Group → ECS Tasks on EC2 instances
2. **Outbound Traffic**: ECS Tasks → NAT Gateway (in public subnets) → Internet Gateway → Internet

### 1.3. Core Design Principles

- **High Availability**: Multi-AZ deployment ensures infrastructure resilience
- **Security**: Private subnets for compute, security groups with least-privilege access, IAM roles for service-to-service authorization
- **Scalability**: Auto Scaling Groups for EC2 instances, ECS Service auto-scaling for tasks
- **Modularity**: Reusable Terraform modules following Single Responsibility Principle
- **Environment Flexibility**: Configuration-driven differences between dev and prod environments

### 1.4. High-Level Architecture

#### Focus on incoming traffic from Internet to containers

![Alt text](docs/diagrams/aws_infrastructure-incoming_traffic.svg "AWS Infrastructure - Incoming Traffic")

#### Focus on outgoing traffic from containers to the other AWS services or the Internet

![Alt text](docs/diagrams/aws_infrastructure-outgoing_traffic.svg "AWS Infrastructure - Outgoing Traffic")

---

## 2. Key Components

| AWS Service | Role in the Architecture |
| :--- | :--- |
| **Route 53 & ACM** | The Route 53 Hosted Zone manages DNS records. AWS Certificate Manager (ACM) provides and validates the SSL certificate, which is attached to the ALB's HTTPS listener to enable secure communication. |
| **Application Load Balancer (ALB)** | Distributes incoming traffic. It listens on Port 443 (HTTPS) and redirects all Port 80 (HTTP) traffic to HTTPS (301 Permanent Redirect). The ALB forwards traffic to an ALB Target Group, which acts as the dynamic list of healthy ECS Tasks. |
| **ECS Task** | The fundamental unit of deployment (the running container). Deployed onto EC2 instances, tasks receive a private IP via `awsvpc` networking and are registered with the ALB Target Group. |
| **Virtual Private Cloud (VPC)** | Provides an isolated network, defining public and private subnets across multiple AZs for high availability. NAT Gateways enable private resources to access the internet. |
| **ECS Service** | The deployment mechanism that defines how many copies of a specific task definition should run on a given ECS cluster, automatically maintaining that desired count and integrating with an Elastic Load Balancer for traffic distribution. |
| **ECS Cluster** | The compute capacity (EC2 instances) running within private subnets. It uses an Auto Scaling Group (ASG) and a Capacity Provider who tells the ECS how to manage the ASG scaling. A critical element in the cluster is the ECS Control Plane, the central component that coordinates containers (i.e., tasks) and ensures cluster wellbeing. Furthermore, each EC2 instance includes an ECS Agent that reports containers health to the Control Plane. |
| **Elastic Container Registry (ECR)** | A private Docker registry storing application container images. Uses priority rules (Rule 1: untagged, Rule 2: tagged) to aggressively expire images while safely retaining a configurable count of environment-tagged (`dev-`, `prod-`) images. |

**For detailed technical documentation** on module architecture, IAM policies, security groups, and resource configurations, see **[AWS Resources Deep Dive](docs/AWS_RESOURCES_DEEP_DIVE.md)**.

---

## 3. Environment Configuration Differences

The infrastructure supports two environments (`dev` and `prod`) with configuration-driven differences to balance cost, performance, and reliability.

| Component | Setting | dev | prod | Rationale |
|-----------|---------|-----|------|-----------|
| **VPC** | NAT Gateway | Single (one_nat_gateway = true) | Multiple (one per AZ) | Cost savings in dev; high availability in prod |
| **ECR** | Tagged Image Retention | 3 images | 10 images | Minimal storage in dev; deeper rollback history in prod |
| **ECS Cluster (ASG)** | Min Instances | 1 | 2 | Lower baseline cost in dev; always-on capacity in prod |
| **ECS Cluster (ASG)** | Max Instances | 2 | 4 | Limited scaling in dev; room for growth in prod |
| **ECS Cluster** | Max Utilization | 100% | 75% | Run instances at full capacity in dev; maintain scaling buffer in prod |
| **ECS Cluster (ASG)** | Scale-In Protection | false | true | Quick teardown in dev; protect running tasks in prod |
| **ECS Service** | Task Placement | binpack:cpu | spread:az, spread:instanceId | Cost optimization in dev; fault tolerance in prod |
| **ALB** | Deletion Protection | false | true | Easy cleanup in dev; prevent accidental deletion in prod |
| **Route 53** | force_destroy | true | false | Allow cleanup in dev; protect domain in prod |

**Configuration File**: `infra-ecs/deployment/common.tfvars`

Example:
```hcl
environment  = "prod"
project_name = "high-availability-app"

# VPC Configuration
single_nat_gateway = false  # prod uses multiple

# ECR Configuration
image_retention_max_count = {
  dev  = 3
  prod = 10
}

# ECS Cluster Configuration
instance_min_size = {
  dev  = 1
  prod = 2
}
instance_max_size = {
  dev  = 2
  prod = 4
}
cluster_max_capacity_provider_reservation = {
  dev  = 100
  prod = 75
}
protect_asg_from_scale_in = {
  dev  = false
  prod = true
}

# ECS Service Configuration
task_placement_strategies = {
  dev = [
    {
      type  = "binpack"
      field = "cpu"
    }
  ]
  prod = [
    {
      type  = "spread"
      field = "attribute:ecs.availability-zone"
    },
    {
      type  = "spread"
      field = "instanceId"
    }
  ]
}
```

---

## 4. CI/CD Workflows

All infrastructure deployment and teardown is managed through **GitHub Actions workflows** located in `.github/workflows/ecs/`. These workflows automate Terraform operations in a dependency-aware order.

### Quick Overview

**Deployment Stages:**
1. **Initial Setup** (Manual) - Deploy S3 state bucket and Route53 hosted zone
2. **Full Deployment** (On push to main) - Complete infrastructure from ECR to running application (10 steps)
3. **Teardown** (Manual) - Clean removal in reverse dependency order

### Workflow Files

- `ecs-deploy-hosted-zone.yaml` - One-time setup of foundational infrastructure
- `ecs-deploy-aws-infra.yaml` - Full deployment pipeline (ECR → SSL → Docker image → VPC → Cluster → ALB → Service → Routing)
- `ecs-destroy-aws-infra.yaml` - Application infrastructure teardown
- `ecs-destroy-hosted-zone.yaml` - DNS and state storage cleanup

### Required GitHub Secrets

- `AWS_ACCESS_KEY_ID` - AWS IAM user access key
- `AWS_SECRET_ACCESS_KEY` - AWS IAM user secret key

**For detailed workflow documentation**, job sequences, manual steps, and troubleshooting, see **[CI/CD Workflows](docs/CICD_WORKFLOWS.md)**.

---

## 5. Terraform Testing

### Running Tests Locally

```bash
cd infra-ecs/
chmod +x run-tests.sh
./run-tests.sh
```

**What It Does**:
- Runs all `.tftest.hcl` files in `tests/unit/` using `terraform test`
- Tests run in **plan mode** (no real AWS resources created)
- Uses mock AWS credentials
- Outputs test results to `test.log`

### Test Coverage

The test suite validates 5 core modules:
- **alb.tftest.hcl** - ALB configuration, listeners, target groups, security groups
- **ecr.tftest.hcl** - Repository configuration, lifecycle policies, image scanning
- **ecs_cluster.tftest.hcl** - Cluster, ASG, Launch Template, IAM configuration
- **ecs_service.tftest.hcl** - Task definition, service configuration, auto-scaling
- **ssl.tftest.hcl** - Certificate configuration, DNS validation, SANs

### CI/CD Integration

Tests automatically run in the `test-terraform-modules` job before any deployment to validate all modules.

**For detailed test suite documentation**, troubleshooting guide, and ECS-specific testing issues, see **[Terraform Testing](docs/TERRAFORM_TESTING.md)**.

---

## 6. Project Structure

```
infra-ecs/
├── deployment/                 # Root modules (environment-specific)
│   ├── backend/                # S3 state bucket
│   ├── ecr/                    # ECR repository
│   ├── hosted_zone/            # Route 53 Hosted Zone
│   ├── ssl/                    # ACM certificate
│   ├── app/                    # Application infrastructure (ECS-specific)
│   │   ├── vpc/                # VPC and networking
│   │   ├── ecs_cluster/        # ECS cluster and ASG
│   │   ├── alb/                # Application Load Balancer
│   │   ├── ecs_service/        # ECS service and tasks
│   │   └── routing/            # Route 53 A records
│   ├── common.tfvars           # Shared configuration
│   ├── domain.tfvars           # Domain-specific configuration
│   ├── backend.tfvars          # Backend configuration
│   └── backend-config.hcl      # Backend initialization config
│
├── modules/                    # Child modules (reusable)
│   ├── alb/                    # ALB module
│   ├── alb_rule/               # ALB listener rule module
│   ├── ecr/                    # ECR module
│   ├── ecs_cluster/            # ECS cluster module
│   ├── ecs_service/            # ECS service module
│   ├── hosted_zone/            # Route 53 Hosted Zone module
│   ├── routing/                # Route 53 routing module
│   └── ssl/                    # ACM certificate module
│
├── tests/                      # Terraform tests
│   ├── unit/                   # Unit tests for modules
│   │   ├── alb.tftest.hcl
│   │   ├── ecr.tftest.hcl
│   │   ├── ecs_cluster.tftest.hcl
│   │   ├── ecs_service.tftest.hcl
│   │   └── ssl.tftest.hcl
│   └── versions.tf             # Provider versions for tests
│
├── docs/                       # Documentation
├── run-tests.sh                # Test runner script
├── test-runner.tf              # Test configuration
└── test.log                    # Test output log
```

---

**For questions or issues, please refer to the [root README](../README.md) or open an issue in the GitHub repository.**
