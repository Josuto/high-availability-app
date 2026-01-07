# ECS Infrastructure Documentation

This directory contains the complete Terraform infrastructure for deploying a high-availability NestJS application using AWS Elastic Container Service (ECS). The implementation follows Infrastructure as Code (IaC) principles with modular, reusable components.

## Table of Contents

1. [High-Level Overview](#1-high-level-overview)
2. [Prerequisites and First-Time Setup](#2-prerequisites-and-first-time-setup)
   - [2.1. Prerequisites](#21-prerequisites)
   - [2.2. Required Configuration Changes](#22-required-configuration-changes)
   - [2.3. Environment-Specific Configuration](#23-environment-specific-configuration-optional)
   - [2.4. DNS Configuration](#24-dns-configuration-post-deployment)
3. [AWS Resources Deep Dive](#3-aws-resources-deep-dive)
   - [3.1. Module Architecture: Root Modules vs Child Modules](#31-module-architecture-root-modules-vs-child-modules)
   - [3.2. Foundational Infrastructure (Approach-Agnostic)](#32-foundational-infrastructure-approach-agnostic)
     - [3.2.1. Elastic Container Registry (ECR)](#321-elastic-container-registry-ecr)
     - [3.2.2. SSL Certificate (ACM)](#322-ssl-certificate-acm)
     - [3.2.3. Route 53 Hosted Zone](#323-route-53-hosted-zone)
   - [3.3. Application Deployment Infrastructure (ECS-Specific)](#33-application-deployment-infrastructure-ecs-specific)
     - [3.3.1. Virtual Private Cloud (VPC)](#331-virtual-private-cloud-vpc)
     - [3.3.2. ECS Cluster](#332-ecs-cluster)
     - [3.3.3. Application Load Balancer (ALB)](#333-application-load-balancer-alb)
     - [3.3.4. ECS Service](#334-ecs-service)
     - [3.3.5. Routing](#335-routing)
     - [3.3.6. IAM Roles and Policies](#336-iam-roles-and-policies)
     - [3.3.7. Security Groups](#337-security-groups)
4. [Environment Configuration Differences](#4-environment-configuration-differences)
5. [CI/CD Workflows](#5-cicd-workflows)
   - [5.1. Initial Setup](#51-initial-setup)
   - [5.2. Full Infrastructure Deployment](#52-full-infrastructure-deployment)
   - [5.3. Infrastructure Teardown](#53-infrastructure-teardown)
6. [Terraform Testing](#6-terraform-testing)
   - [6.1. Running Tests](#61-running-tests)
   - [6.2. Troubleshooting](#62-troubleshooting)
   - [6.3. Test Files Explained](#63-test-files-explained)
7. [Project Structure](#7-project-structure)

---

## 1. High-Level Overview

The ECS infrastructure implements a production-ready, highly available container orchestration platform on AWS. The architecture leverages AWS-native services to provide automated scaling, load balancing, and secure HTTPS communication.

### Key Components and Their Relationships

```
Internet
    ↓
[Route 53] → Points to ALB DNS
    ↓
[Application Load Balancer]
    ↓ (HTTPS:443 / HTTP:80→HTTPS)
[ALB Target Group] ← Health checks ECS Tasks
    ↓
[ECS Tasks] (in awsvpc mode)
    ↓ Running on
[EC2 Instances] (in private subnets)
    ↓ Managed by
[Auto Scaling Group + Capacity Provider]
    ↓ Part of
[ECS Cluster]
```

### Traffic Flow

1. **Inbound Traffic**: User requests hit Route 53 → ALB (validates SSL certificate) → Target Group → ECS Tasks on EC2 instances
2. **Outbound Traffic**: ECS Tasks → NAT Gateway (in public subnets) → Internet Gateway → Internet

### Core Design Principles

- **High Availability**: Multi-AZ deployment ensures infrastructure resilience
- **Security**: Private subnets for compute, security groups with least-privilege access, IAM roles for service-to-service authorization
- **Scalability**: Auto Scaling Groups for EC2 instances, ECS Service auto-scaling for tasks
- **Modularity**: Reusable Terraform modules following Single Responsibility Principle
- **Environment Flexibility**: Configuration-driven differences between dev and prod environments

---

## 2. Prerequisites and First-Time Setup

Before deploying this infrastructure, you need to configure several variables and files with your own values. This section guides you through all required configuration changes.

### 2.1. Prerequisites

Ensure you have the following before starting:

- **AWS Account** with appropriate IAM permissions to create VPC, ECS, ALB, Route53, ACM, ECR, and IAM resources
- **Domain Name** registered at any domain registrar (e.g., GoDaddy, Namecheap, Route53)
- **Terraform 1.0+** installed locally ([Installation Guide](https://developer.hashicorp.com/terraform/downloads))
- **AWS CLI** installed and configured ([Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **(Optional) GitHub Repository** if you plan to use the included CI/CD workflows
- **(Optional) Pre-commit Tools** for local development: TFLint, tfsec, detect-secrets, terraform-docs

### 2.2. Required Configuration Changes

You must update the following configuration files before deployment. All files are located in `infra-ecs/deployment/`.

#### Step 1: Configure S3 Backend for Terraform State

Update **both files** with your unique S3 bucket name:

**File 1:** `infra-ecs/deployment/backend.tfvars`
```hcl
# S3 bucket name for Terraform state storage
state_bucket_name = "your-unique-bucket-name"
```

**File 2:** `infra-ecs/deployment/backend-config.hcl`
```hcl
# Must match the value in backend.tfvars
bucket = "your-unique-bucket-name"

# Optional: Uncomment if you enable DynamoDB state locking
# dynamodb_table = "your-terraform-locks-table"
```

**Critical**: Both values **must match** exactly. The bucket name must be globally unique across all AWS accounts.

**Example:**
```hcl
state_bucket_name = "mycompany-terraform-state-bucket"
bucket = "mycompany-terraform-state-bucket"
```

---

#### Step 2: Configure Project Name and Environment

Edit `infra-ecs/deployment/common.tfvars`:

```hcl
# Project identifier (used for resource naming and tagging)
project_name = "your-project-name"

# Environment identifier: "dev" or "prod"
environment = "dev"
```

**Guidelines:**
- `project_name`: Short, lowercase, alphanumeric (e.g., `myapp`, `webapp`, `api`)
- `environment`: Must be either `"dev"` or `"prod"` (affects resource configuration)

**Example:**
```hcl
project_name = "myapp"
environment = "prod"
```

**Impact:** These values determine resource naming patterns:
- ECS Cluster: `${environment}-${project_name}-ecs-cluster` → `prod-myapp-ecs-cluster`
- ALB: `${environment}-${project_name}-alb` → `prod-myapp-alb`
- ECR Repository: `${environment}-${project_name}-ecr-repository` → `prod-myapp-ecr-repository`

---

#### Step 3: Configure Your Domain Name

Edit `infra-ecs/deployment/domain.tfvars`:

```hcl
# Your root domain name (must be a domain you own)
root_domain = "yourdomain.com"
```

**Example:**
```hcl
root_domain = "example.com"
```

**What This Configures:**
- SSL Certificate will be issued for: `example.com` and `*.example.com`
- Route 53 A records will be created for: `example.com` and `www.example.com`

---

#### Step 4: (Optional) Change AWS Region

By default, the infrastructure deploys to `eu-west-1`. To use a different region:

**A. Update GitHub Workflows** (if using CI/CD):

Edit `.github/workflows/ecs/*.yaml` files:
```yaml
env:
  AWS_REGION: your-preferred-region  # Change from eu-west-1
  TERRAFORM_VERSION: 1.10.3
```

**B. Update Backend Configuration:**

Edit `infra-ecs/deployment/backend-config.hcl` and add the region parameter:
```hcl
bucket = "your-unique-bucket-name"
region = "your-preferred-region"  # Add this line
```

**C. Update Terraform Init Commands:**

When running `terraform init` manually, specify the region:
```bash
terraform init -backend-config="../backend-config.hcl" -backend-config="region=your-preferred-region"
```

---

#### Step 5: Configure GitHub Secrets (For CI/CD Only)

If you plan to use the GitHub Actions workflows, add these secrets to your repository:

**Navigate to:** GitHub Repository → Settings → Secrets and variables → Actions → New repository secret

**Required Secrets:**
- **Name:** `AWS_ACCESS_KEY_ID`
  - **Value:** Your AWS IAM user access key
- **Name:** `AWS_SECRET_ACCESS_KEY`
  - **Value:** Your AWS IAM user secret key

**IAM Permissions Required:**
The IAM user needs permissions for: VPC, EC2, ECS, ECR, ALB, Route53, ACM, IAM, CloudWatch, Auto Scaling, S3 (for state), and optionally DynamoDB (for locking).

**Security Best Practice:** Create a dedicated IAM user for CI/CD with least-privilege permissions.

---

### 2.3. Environment-Specific Configuration (Optional)

The infrastructure supports different resource configurations for `dev` and `prod` environments through configuration maps defined in `common.tfvars`.

**Default Configuration:**
The repository includes sensible defaults for both environments. For most use cases, you **do not need to modify** these values.

**Advanced Configuration:**
If you want to customize environment-specific settings (e.g., instance sizes, scaling limits, NAT gateway configuration), refer to [Section 4: Environment Configuration Differences](#4-environment-configuration-differences) for a complete explanation of all available settings.

**Example Settings:**
- NAT Gateway count (single vs multi-AZ)
- ECR image retention (3 images in dev, 10 in prod)
- Auto Scaling Group min/max instances
- Task placement strategies (binpack vs spread)

---

### 2.4. DNS Configuration (Post-Deployment)

After deploying the Route 53 Hosted Zone (see [Section 5.1: Initial Setup](#51-initial-setup)), you must **manually update DNS nameservers** at your domain registrar.

**Steps:**

1. **Deploy the Hosted Zone** using the `ecs-deploy-hosted-zone.yaml` workflow or Terraform

2. **Retrieve Nameservers** from AWS Console:
   - Navigate to: AWS Console → Route 53 → Hosted Zones
   - Click on your hosted zone
   - Copy the 4 NS (nameserver) records, which look like:
     ```
     ns-123.awsdns-45.com
     ns-678.awsdns-90.net
     ns-1234.awsdns-56.org
     ns-5678.awsdns-12.co.uk
     ```

3. **Update DNS at Your Domain Registrar:**
   - Log in to your domain registrar (GoDaddy, Namecheap, etc.)
   - Navigate to DNS management / Nameserver settings
   - Replace existing nameservers with the 4 Route 53 nameservers
   - Save changes

4. **Wait for DNS Propagation:**
   - Propagation typically takes 5-60 minutes
   - Can take up to 48 hours in rare cases
   - **Verify propagation** before proceeding:
     ```bash
     dig NS yourdomain.com
     # or
     nslookup -type=NS yourdomain.com
     ```

5. **Proceed with SSL Certificate Deployment:**
   - Once DNS propagation is complete, the SSL certificate validation will succeed
   - The ACM certificate validation depends on functioning DNS

**Warning:** If you attempt to deploy the SSL certificate before DNS propagation completes, the validation will fail and the deployment will hang or timeout.

---

## 3. AWS Resources Deep Dive

### 3.1. Module Architecture: Root Modules vs Child Modules

The infrastructure follows a strict separation between **Root Modules** (deployment stages) and **Child Modules** (reusable components), implementing the Single Responsibility Principle and maximizing reusability.

#### Child Modules (`infra-ecs/modules/*`)

Child modules are **single-purpose, reusable infrastructure components** that define specific AWS resources:
- Examples: `ecr`, `alb`, `ecs_cluster`, `ecs_service`, `ssl`, `hosted_zone`, `routing`
- Accept inputs via variables (e.g., `var.vpc_id`, `var.project_name`)
- Return outputs (e.g., `alb_dns_name`, `ecs_cluster_arn`)
- **No knowledge** of other modules or deployment stages
- **No remote state references** - completely self-contained
- Designed for maximum portability and reusability across projects

#### Root Modules (`infra-ecs/deployment/*`)

Root modules are **environment-specific orchestration layers** that:
- Stitch child modules together to create complete infrastructure stages
- Use `data "terraform_remote_state"` to read outputs from previous deployment stages
- Pass environment-specific configuration to child modules
- Examples: `deployment/app/vpc`, `deployment/app/ecs_cluster`, `deployment/app/alb`

#### How They Work Together

**Example 1: ECS Service depends on outputs from VPC, Cluster, and ALB**

The `deployment/app/ecs_service/` root module:
1. Reads VPC outputs from `deployment/app/vpc/` remote state:
   ```hcl
   data "terraform_remote_state" "vpc" {
     backend = "s3"
     config = {
       bucket = "terraform-state-bucket"
       key    = "deployment/app/vpc/terraform.tfstate"
       region = "eu-west-1"
     }
   }
   ```

2. Reads ECS cluster outputs from `deployment/app/ecs_cluster/` remote state:
   ```hcl
   data "terraform_remote_state" "ecs_cluster" {
     backend = "s3"
     config = {
       bucket = "terraform-state-bucket"
       key    = "deployment/app/ecs_cluster/terraform.tfstate"
       region = "eu-west-1"
     }
   }
   ```

3. Passes these values to the `ecs_service` child module:
   ```hcl
   module "ecs_service" {
     source = "../../../modules/ecs_service"

     vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id
     vpc_private_subnets        = data.terraform_remote_state.vpc.outputs.private_subnets
     ecs_cluster_arn            = data.terraform_remote_state.ecs_cluster.outputs.cluster_arn
     alb_target_group_id        = data.terraform_remote_state.alb.outputs.target_group_arn
     alb_security_group_id      = data.terraform_remote_state.alb.outputs.alb_security_group_id
   }
   ```

**Example 2: Deployment Order and Dependencies**

The deployment stages must be executed in dependency order:
1. `backend/` → Creates S3 state bucket (no dependencies)
2. `hosted_zone/` → Creates Route53 zone (no dependencies)
3. `ssl/` → Requires outputs from `hosted_zone/` (reads hosted_zone_id)
4. `ecr/` → Creates ECR repository (no dependencies)
5. `app/vpc/` → Creates network infrastructure (no dependencies)
6. `app/ecs_cluster/` → Requires outputs from `vpc/` (reads vpc_id, private_subnets)
7. `app/alb/` → Requires outputs from `vpc/` and `ssl/` (reads vpc_id, public_subnets, certificate_arn)
8. `app/ecs_service/` → Requires outputs from `vpc/`, `ecs_cluster/`, and `alb/`
9. `app/routing/` → Requires outputs from `hosted_zone/` and `alb/` (reads zone_id, alb_dns_name)

**Why This Architecture?**

- **Reusability**: The `alb` child module can be used in any project that needs an Application Load Balancer, without copying VPC or ECS code
- **Separation of Concerns**: Each child module has a single responsibility (e.g., ALB module only manages load balancer resources)
- **Staged Deployment**: Root modules enable deploying infrastructure in logical stages with clear dependencies
- **Environment Isolation**: Different environments (dev, prod) use the same child modules with different configuration values
- **State Isolation**: Each deployment stage has its own Terraform state file, reducing blast radius of changes

---

### 3.2. Foundational Infrastructure (Approach-Agnostic)

These root modules represent **approach-agnostic infrastructure** - components that are shared between different container orchestration approaches (ECS and EKS implementations). They reside directly under `infra-ecs/deployment/` and provide foundational services required by any application deployment.

**Approach-Agnostic Modules:**
- **`backend/`**: S3 bucket for Terraform remote state storage
- **`hosted_zone/`**: Route53 hosted zone for DNS management (see [Section 3.2.3](#323-route-53-hosted-zone))
- **`ssl/`**: ACM SSL certificate for HTTPS (see [Section 3.2.2](#322-ssl-certificate-acm))
- **`ecr/`**: Docker container registry (see [Section 3.2.1](#321-elastic-container-registry-ecr))

**Key Characteristic:** These modules are not specific to ECS - the same modules are also used in the EKS implementation (`infra-eks/`), providing shared infrastructure across both approaches.

---

#### 3.2.1. Elastic Container Registry (ECR)

**Purpose**: Private Docker registry for storing application container images.

**Key Features**:
- **Image Tag Mutability**: Set to `IMMUTABLE` to prevent tag overwrites, ensuring image integrity and reliable rollbacks
- **Image Scanning**: Automatic vulnerability scanning on push (`scan_on_push = true`)
- **Lifecycle Policy**: Automated image retention and cleanup with two priority rules:
  - **Rule 1 (Priority 1)**: Keep only 1 untagged image, aggressively expire the rest
  - **Rule 2 (Priority 2)**: Keep environment-tagged images (e.g., `dev-abc123`, `prod-def456`) based on retention count

**Environment Differences**:
| Setting | dev | prod | Rationale |
|---------|-----|------|-----------|
| Tagged Image Retention | 3 images | 10 images | Storage cost vs rollback depth |

**Naming Convention**: `${environment}-${project_name}-ecr-repository` <br>
**Module Location**: `infra-ecs/modules/ecr/` <br>
**Deployment Location**: `infra-ecs/deployment/ecr/`

**CI/CD Integration**: Docker images are built and pushed with tags following `${environment}-${git_sha}` format.

---

#### 3.2.2. SSL Certificate (ACM)

**Purpose**: Provides SSL/TLS certificate for secure HTTPS communication.

**Key Features**:
- **Validation Method**: DNS (automated, no manual email approval required)
- **Domain Coverage**:
  - **Primary Domain**: Root domain (e.g., `example.com`)
  - **Subject Alternative Name (SAN)**: Wildcard domain (e.g., `*.example.com`)
- **DNS Validation Records**: Automatically created in Route 53 Hosted Zone
  - **TTL**: 60 seconds for faster propagation
  - **Allow Overwrite**: Enabled for redeployments
- **Lifecycle Rule**: `create_before_destroy = true` ensures zero-downtime certificate rotation

**Validation Workflow**:
1. ACM certificate request created with DNS validation
2. Validation DNS records (CNAME) created in Route 53
3. `aws_acm_certificate_validation` resource waits for validation to complete
4. Validated certificate ARN becomes available for ALB attachment

**Module Location**: `infra-ecs/modules/ssl/` <br>
**Deployment Location**: `infra-ecs/deployment/ssl/`

**Prerequisites**:
- Route 53 Hosted Zone must exist
- Domain DNS nameservers must point to Route 53 nameservers
- DNS propagation must be complete (can take minutes to hours)

---

#### 3.2.3. Route 53 Hosted Zone

**Purpose**: Manages DNS namespace for the domain.

**Key Features**:
- **Purpose**: Central DNS management for the domain
- **Created During**: Initial setup (before SSL certificate)
- **Nameservers**: Must be configured at domain registrar after creation
- **Force Destroy**: Enabled for dev, disabled for prod (protects production domain)

**Environment Differences**:
| Setting | dev | prod | Rationale |
|---------|-----|------|-----------|
| Hosted Zone force_destroy | true | false | Quick cleanup vs domain protection |

**Module Location**: `infra-ecs/modules/hosted_zone/` <br>
**Deployment Location**: `infra-ecs/deployment/hosted_zone/`

**Note**: DNS records (A records) that point to the Application Load Balancer are created by the approach-specific routing module (see [Section 3.3.5](#335-routing)).

---

### 3.3. Application Deployment Infrastructure (ECS-Specific)

These root modules represent **ECS-specific application infrastructure** - components that are unique to the ECS cluster-based container orchestration approach. They reside under `infra-ecs/deployment/app/` and implement the compute, networking, and load balancing layers specific to running containers on ECS with EC2 instances.

**ECS-Specific Modules:**
- **`app/vpc/`**: Network infrastructure for ECS deployment (see [Section 3.3.1](#331-virtual-private-cloud-vpc))
- **`app/ecs_cluster/`**: ECS cluster with EC2 Auto Scaling Group (see [Section 3.3.2](#332-ecs-cluster))
- **`app/alb/`**: Application Load Balancer for traffic distribution (see [Section 3.3.3](#333-application-load-balancer-alb))
- **`app/ecs_service/`**: ECS service managing containerized tasks (see [Section 3.3.4](#334-ecs-service))
- **`app/routing/`**: Route 53 A records pointing to ALB (see [Section 3.3.5](#335-routing))

**Key Characteristic:** These modules implement ECS-specific concepts (clusters, services, tasks, capacity providers) and would be replaced by different modules in the EKS implementation (node groups, pods, deployments).

The following subsections provide detailed explanations of each infrastructure component, organized by category.

---

#### 3.3.1. Virtual Private Cloud (VPC)

**Purpose**: Provides isolated network infrastructure for all AWS resources.

**Key Features**:
- **Multi-AZ Architecture**: Spans multiple Availability Zones for fault tolerance
- **Subnet Strategy**:
  - **Public Subnets**: Host NAT Gateways and Application Load Balancer
  - **Private Subnets**: Host EC2 instances running ECS tasks, isolated from direct internet access
- **NAT Gateway**: Enables outbound internet connectivity for resources in private subnets (e.g., pulling Docker images, accessing AWS services)
- **Internet Gateway**: Provides internet access to resources in public subnets

**Environment Differences**:
| Setting | dev | prod | Rationale |
|---------|-----|------|-----------|
| NAT Gateway | Single (one_nat_gateway = true) | Multiple (one per AZ) | Cost savings vs high availability |

**Module Location**: Uses the official `terraform-aws-modules/vpc/aws` module <br>
**Deployment Location**: `infra-ecs/deployment/app/vpc/`

---

#### 3.3.2. ECS Cluster

**Purpose**: Provides the compute capacity (EC2 instances) for running containerized applications.

**Key Components**:

#### a) ECS Cluster Resource
- Central orchestration component managed by AWS ECS Control Plane
- Coordinates container placement and health monitoring
- Each EC2 instance runs an ECS Agent that reports to the Control Plane

#### b) Auto Scaling Group (ASG)
- Manages the pool of EC2 instances
- **Health Check**: EC2 health checks with 300-second grace period
- **Scaling**: Triggered by ECS Capacity Provider based on container resource utilization
- **Scale-In Protection**: Prevents termination of instances currently hosting tasks (prod only)
- **Tag Requirement**: Must include `AmazonECSManaged = true` tag for Capacity Provider integration

#### c) Launch Template
- Defines EC2 instance configuration
- **AMI**: Uses ECS-optimized Amazon Linux 2023 AMI (retrieved via SSM parameter)
- **Instance Metadata Service v2 (IMDSv2)**: Required (`http_tokens = "required"`) for enhanced security
- **IAM Instance Profile**: Attaches `ecs_instance_role` for EC2-level permissions
- **User Data**: Configures EC2 instance to join the ECS cluster

#### d) Capacity Provider
- Bridges ECS Service and Auto Scaling Group
- **Managed Scaling**: Automatically adjusts EC2 instance count based on task requirements
- **Target Utilization**: Maintains cluster at configured capacity utilization (100% dev, 75% prod)
- **Managed Termination Protection**: Enabled to prevent premature instance termination

**Environment Differences**:
| Setting | dev | prod | Rationale |
|---------|-----|------|-----------|
| Min/Max Instances (ASG) | 1/2 | 2/4 | Cost vs baseline capacity |
| Cluster Max Utilization | 100% | 75% | Cost optimization vs scaling buffer |
| Scale-In Protection (ASG) | false | true | Quick teardown vs stability |

**Naming Convention**: `${environment}-${project_name}-ecs-cluster` <br>
**Module Location**: `infra-ecs/modules/ecs_cluster/` <br>
**Deployment Location**: `infra-ecs/deployment/app/ecs_cluster/`

---

#### 3.3.3. Application Load Balancer (ALB)

**Purpose**: Distributes incoming HTTPS/HTTP traffic across healthy ECS tasks.

**Key Components**:

#### a) ALB Resource
- **Type**: Application Load Balancer (Layer 7)
- **Scheme**: Internet-facing (public)
- **Subnets**: Deployed in public subnets across multiple AZs
- **Security**: `drop_invalid_header_fields = true` for enhanced security
- **Deletion Protection**: Disabled for dev, enabled for prod

#### b) HTTPS Listener (Port 443)
- **SSL Policy**: `ELBSecurityPolicy-TLS13-1-2-Res-2021-06` (modern, restrictive TLS policy)
- **Certificate**: Attaches validated ACM certificate from SSL module
- **Default Action**: Forward to Target Group

#### c) HTTP Listener (Port 80)
- **Default Action**: Redirect to HTTPS with 301 permanent redirect
- **Purpose**: Ensures all traffic uses encrypted HTTPS connections

#### d) Target Group
- **Protocol**: HTTP (backend communication between ALB and tasks)
- **Port**: Matches container port (default: 3000)
- **Target Type**: IP (required for `awsvpc` network mode)
- **Health Check**:
  - **Path**: Configurable (default: `/health`)
  - **Interval**: 30 seconds
  - **Timeout**: 5 seconds
  - **Healthy Threshold**: 2 consecutive successes
  - **Unhealthy Threshold**: 2 consecutive failures
  - **Matcher**: HTTP 200 status code
- **Deregistration Delay**: 30 seconds (time to drain existing connections before removing target)

**Environment Differences**:
| Setting | dev | prod | Rationale |
|---------|-----|------|-----------|
| Deletion Protection | false | true | Flexibility vs safety |

**Naming Convention**: `${environment}-${project_name}-alb` <br>
**Module Location**: `infra-ecs/modules/alb/` <br>
**Deployment Location**: `infra-ecs/deployment/app/alb/`

---

#### 3.3.4. ECS Service

**Purpose**: Defines and maintains the desired state of running application containers (tasks).

**Key Components**:

#### a) ECS Task Definition
- Defines container configuration: image, CPU, memory, port mappings
- **Network Mode**: `awsvpc` - Each task receives its own Elastic Network Interface (ENI) with a private IP
- **Container Definition**:
  - **Image**: Pulled from ECR repository
  - **Port Mapping**: Exposes container port (default: 3000)
  - **Logging**: CloudWatch Logs integration with `awslogs` driver
  - **Essential**: Set to `true` - task fails if this container stops

#### b) ECS Service
- Maintains desired count of running tasks
- **Deployment Configuration**:
  - **Minimum Healthy Percent**: 50% (allows rolling updates with temporary capacity reduction)
  - **Maximum Percent**: 200% (allows new tasks to start before old ones stop)
- **Load Balancer Integration**: Registers tasks with ALB Target Group
- **Capacity Provider Strategy**: Uses cluster's capacity provider for EC2-based task placement
- **Network Configuration**: Places tasks in private subnets with `ecs-tasks-sg` security group

#### c) Task Placement Strategy
Determines how tasks are distributed across EC2 instances:
- **dev**: `binpack` on CPU (pack as many tasks as possible on fewer instances for cost savings)
- **prod**: `spread` across AZs, then `spread` across instances (maximize fault tolerance)

#### d) Task Auto Scaling (Optional)
- **Target Tracking Policy**: Scales task count based on ECS Service average CPU utilization
- **Min/Max Capacity**: Configurable per environment
- **Scale-In Cooldown**: 60 seconds (prevents rapid scale-in after scale-out)
- **Scale-Out Cooldown**: 60 seconds

**Environment Differences**:
| Setting | dev | prod | Rationale |
|---------|-----|------|-----------|
| Task Placement | binpack:cpu | spread:az, spread:instanceId | Cost vs fault tolerance |

**Naming Convention**: `${environment}-${project_name}-ecs-service` <br>
**Module Location**: `infra-ecs/modules/ecs_service/` <br>
**Deployment Location**: `infra-ecs/deployment/app/ecs_service/`

---

#### 3.3.5. Routing

**Purpose**: Creates DNS records (A records) that route traffic from the domain to the Application Load Balancer.

**Key Features**:
- **Root Domain**: Points to ALB (e.g., `example.com` → ALB DNS)
- **WWW Subdomain**: Points to ALB (e.g., `www.example.com` → ALB DNS)
- **Record Type**: A record with alias to ALB
- **Evaluate Target Health**: Enabled (Route 53 checks ALB health)
- **Data Source**: ALB DNS name and zone ID are read from ALB outputs via remote state

**Dependencies**:
- **hosted_zone**: Requires hosted zone ID from foundational infrastructure
- **alb**: Requires ALB DNS name and hosted zone ID (ECS-specific)

**Why This Is ECS-Specific**:
The routing module depends on outputs from the `alb` deployment, which is created directly by Terraform as part of the ECS infrastructure. In the EKS implementation, routing depends on the ALB created dynamically by the AWS Load Balancer Controller, making each routing implementation approach-specific.

**Module Location**: `infra-ecs/modules/routing/` <br>
**Deployment Location**: `infra-ecs/deployment/app/routing/`

---

#### 3.3.6. IAM Roles and Policies

The infrastructure uses two distinct IAM roles for different levels of authorization.

#### a) ECS EC2 Instance Role (`ecs_instance_role`)

**Assumed By**: EC2 container instances in the ECS cluster

**Purpose**: Grants EC2 instances permissions to interact with AWS services at the infrastructure level.

**Managed Policies Attached**:
1. **AmazonEC2ContainerServiceforEC2Role** (`arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role`)
   - Allows EC2 instance to register as a container instance with ECS cluster
   - Permissions: `ecs:RegisterContainerInstance`, `ecs:DeregisterContainerInstance`, `ecs:SubmitContainerStateChange`, `ecs:SubmitTaskStateChange`

2. **AmazonSSMManagedInstanceCore** (`arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore`)
   - Enables AWS Systems Manager Session Manager for secure shell access
   - Eliminates need for SSH keys and bastion hosts
   - Permissions: `ssm:UpdateInstanceInformation`, `ssmmessages:*`, `ec2messages:*`

**Custom Inline Policy** (`ecs_instance_policy`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

**Why This Matters**:
- **ECR Access**: Allows EC2 instances to authenticate with ECR and pull Docker images
- **CloudWatch Logs**: Enables operational logging from EC2 instance-level processes

**Module Location**: `infra-ecs/modules/ecs_cluster/iam.tf`

---

#### b) ECS Task Execution Role (`ecs_task_execution_role`)

**Assumed By**: ECS tasks (via the ECS agent)

**Purpose**: Grants the ECS service permissions to perform actions on behalf of your tasks.

**Managed Policy Attached**:
- **AmazonECSTaskExecutionRolePolicy** (`arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy`)
  - Allows ECS to pull container images from ECR
  - Allows ECS to write container application logs to CloudWatch
  - Permissions: `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:GetDownloadUrlForLayer`, `ecr:BatchGetImage`, `logs:CreateLogStream`, `logs:PutLogEvents`

**Custom Inline Policy** (`ecs_task_execution_policy`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/ecs/*"
    }
  ]
}
```

**Why This Matters**:
- **Image Pull**: ECS service pulls Docker images during task startup
- **Application Logs**: Container stdout/stderr is written to CloudWatch Log Group (`/ecs/${project_name}`)

**Module Location**: `infra-ecs/modules/ecs_service/iam.tf`

---

#### Trust Relationships

Both roles use trust policies to define which AWS services can assume them:

**ECS Instance Role Trust Policy** (allows EC2 service):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**ECS Task Execution Role Trust Policy** (allows ECS tasks service):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

---

#### 3.3.7. Security Groups

Security Groups act as virtual firewalls, controlling network traffic at the resource level.

#### a) ALB Security Group (`alb-sg`)

**Attached To**: Application Load Balancer

**Purpose**: Controls public internet access to the load balancer.

**Ingress Rules**:
| Port | Protocol | Source | Description |
|------|----------|--------|-------------|
| 443 | TCP | 0.0.0.0/0 | HTTPS traffic from internet |
| 80 | TCP | 0.0.0.0/0 | HTTP traffic (redirects to HTTPS) |

**Egress Rules**:
| Port | Protocol | Destination | Description |
|------|----------|-------------|-------------|
| All | All | 0.0.0.0/0 | Allow all outbound traffic to ECS tasks |

**Module Location**: `infra-ecs/modules/alb/security_groups.tf`

---

#### b) ECS Tasks Security Group (`ecs-tasks-sg`)

**Attached To**: ECS tasks (via awsvpc network mode)

**Purpose**: Restricts access to application containers to only the ALB.

**Ingress Rules**:
| Port | Protocol | Source | Description |
|------|----------|--------|-------------|
| 3000 (container_port) | TCP | alb-sg | Traffic only from ALB |

**Egress Rules**:
| Port | Protocol | Destination | Description |
|------|----------|-------------|-------------|
| All | All | 0.0.0.0/0 | Allow outbound (NAT Gateway, AWS APIs) |

**Why This Matters**: Prevents direct internet access to containers. All traffic must flow through the ALB, which provides SSL termination, WAF integration points, and centralized access logging.

**Module Location**: `infra-ecs/modules/ecs_service/security_groups.tf`

---

#### c) ECS Cluster Security Group (`cluster-sg`)

**Attached To**: EC2 instances in the ECS cluster

**Purpose**: Allows EC2 instances to communicate with AWS services and perform management operations.

**Ingress Rules**: None (no inbound traffic to EC2 instances directly)

**Egress Rules**:
| Port | Protocol | Destination | Description |
|------|----------|-------------|-------------|
| All | All | 0.0.0.0/0 | Allow all outbound (ECS Agent, image pulls, patching) |

**Module Location**: `infra-ecs/modules/ecs_cluster/security_groups.tf`

---

## 4. Environment Configuration Differences

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

## 5. CI/CD Workflows

All infrastructure deployment and teardown is managed through GitHub Actions workflows located in `.github/workflows/ecs/`. These workflows automate Terraform operations in a dependency-aware order.

### Workflow Overview

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

### 5.1. Initial Setup

**Workflow**: `ecs-deploy-hosted-zone.yaml`
**Trigger**: Manual (`workflow_dispatch`)
**Purpose**: One-time setup of foundational infrastructure

#### Jobs Sequence

1. **deploy-terraform-state-bucket**
   - Creates S3 bucket for Terraform remote state storage
   - Enables versioning for state file history
   - **Reusable Workflow**: Calls `ecs-deploy-terraform-state-bucket.yaml`

2. **deploy-hosted-zone** (depends on: deploy-terraform-state-bucket)
   - Creates Route 53 Hosted Zone for the domain
   - Initializes Terraform with remote state backend
   - Runs `terraform plan` and `terraform apply` in `infra-ecs/deployment/hosted_zone/`
   - **Required Variables**: `common.tfvars` (project_name, environment), `domain.tfvars` (root_domain_name)

#### Manual Steps Required After Workflow

1. **Navigate to AWS Console** → Route 53 → Hosted Zones
2. **Copy the nameserver (NS) records** (4 values like `ns-123.awsdns-45.com`)
3. **Update DNS at your domain registrar** with the Route 53 nameservers
4. **Wait for DNS propagation** (can take 5 minutes to 48 hours, typically < 1 hour)
5. **Verify propagation**: Run `dig NS yourdomain.com` or use online DNS checkers

**Why This Matters**: The SSL certificate validation in the next workflow requires functioning DNS. If DNS hasn't propagated, the certificate validation will fail.

---

### 5.2. Full Infrastructure Deployment

**Workflow**: `ecs-deploy-aws-infra.yaml`
**Trigger**: Push to `main` branch
**Purpose**: Complete infrastructure deployment from ECR to running application

#### Jobs Sequence

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

#### Workflow Environment Variables

```yaml
env:
  AWS_REGION: eu-west-1
  TERRAFORM_VERSION: 1.10.3
```

#### Secrets Required

- `AWS_ACCESS_KEY_ID`: AWS IAM user access key
- `AWS_SECRET_ACCESS_KEY`: AWS IAM user secret key

---

### 5.3. Infrastructure Teardown

**Workflows**: `ecs-destroy-aws-infra.yaml` and `ecs-destroy-hosted-zone.yaml`
**Trigger**: Manual (`workflow_dispatch`)
**Purpose**: Clean removal of all infrastructure in reverse dependency order

#### Workflow 1: ecs-destroy-aws-infra.yaml

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

#### Workflow 2: ecs-destroy-hosted-zone.yaml

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

## 6. Terraform Testing

### 6.1. Running Tests

**Test Runner**: `infra-ecs/run-tests.sh`

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

**CI/CD Integration**: Tests automatically run in the `test-terraform-modules` job before any deployment.

---

### 6.2. Troubleshooting

For general troubleshooting advice on Terraform testing (test failures, permission errors, Terraform version issues, etc.), refer to the [Troubleshooting section in docs/TESTING.md](../docs/TESTING.md#troubleshooting).

This section covers ECS-specific testing issues:

#### ECS Cluster Module Fails to Initialize

If you see "Failed to initialize ecs_cluster for validation", you need mock AWS credentials:

```bash
# The ecs_cluster module has data sources that require AWS credentials
export AWS_ACCESS_KEY_ID="mock-access-key"
export AWS_SECRET_ACCESS_KEY="mock-secret-key" # pragma: allowlist secret
export AWS_DEFAULT_REGION="eu-west-1"
./run-tests.sh
```

**Why this is needed:**
- The ecs_cluster module queries AWS SSM Parameter Store for ECS-optimized AMI IDs
- Terraform requires credentials to initialize the AWS provider, even for validation
- Mock credentials satisfy this requirement without making actual AWS API calls
- CI/CD pipeline automatically provides these credentials

---

### 6.3. Test Files Explained

All test files use Terraform's native testing framework (introduced in Terraform 1.6+). Tests use mock AWS credentials and validate module configuration without creating real resources.

---

#### 6.3.1. alb.tftest.hcl

**Module Tested**: `modules/alb/` <br>
**Purpose**: Validates ALB configuration, listeners, target groups, and security groups.

**Test Suites**:

1. **alb_valid_configuration**
   - Verifies ALB naming convention: `${environment}-${project_name}-alb`
   - Confirms ALB is internet-facing (`internal = false`)
   - Validates security setting: `drop_invalid_header_fields = true`
   - Checks deletion protection is disabled for dev environment

2. **alb_production_configuration**
   - Confirms deletion protection is enabled for prod environment
   - **Why**: Prevents accidental deletion of production load balancer

3. **alb_listeners_configured**
   - **HTTPS Listener (Port 443)**:
     - Port and protocol validation
     - SSL policy check: `ELBSecurityPolicy-TLS13-1-2-Res-2021-06`
     - **Why**: Ensures modern, secure TLS configuration
   - **HTTP Listener (Port 80)**:
     - Validates redirect to HTTPS (type: `redirect`)
     - Confirms 301 permanent redirect status code
     - **Why**: Enforces HTTPS for all traffic

4. **alb_target_group_configured**
   - Validates target group port matches container port
   - Confirms HTTP protocol for backend communication
   - Checks deregistration delay configuration (default: 30s)
   - Validates health check path and matcher (HTTP 200)
   - **Why**: Ensures proper traffic routing and health monitoring

5. **alb_security_group_rules**
   - Confirms security group is in correct VPC
   - Validates HTTPS (443) and HTTP (80) ingress rules
   - Confirms egress rules allow outbound traffic to ECS tasks
   - **Why**: Ensures proper network access control

6. **alb_tags_applied**
   - Validates ALB resource is created with a name
   - **Why**: Confirms basic resource creation

---

#### 6.3.2. ecr.tftest.hcl

**Module Tested**: `modules/ecr/` <br>
**Purpose**: Validates ECR repository configuration, security settings, and lifecycle policies.

**Test Suites**:

1. **ecr_repository_basic_configuration**
   - Verifies repository naming: `${environment}-${project_name}-ecr-repository`
   - Confirms image tag mutability is `IMMUTABLE`
   - **Why**: Prevents tag overwrites, ensures reliable rollbacks
   - Validates scan_on_push is enabled for vulnerability scanning

2. **ecr_repository_tagging**
   - Confirms project name is included in repository name
   - **Why**: Maintains naming consistency

3. **ecr_lifecycle_policy_exists**
   - Validates lifecycle policy is attached to repository
   - Confirms policy is defined (length > 0)
   - **Why**: Ensures automated image cleanup

4. **ecr_lifecycle_policy_untagged_images**
   - Validates policy includes rule for untagged images
   - Confirms retention count of 1 for untagged images
   - **Why**: Aggressively cleans up temporary/failed builds

5. **ecr_lifecycle_policy_dev_retention**
   - Validates policy uses `dev-` tag prefix
   - Confirms retention count matches dev configuration (e.g., 5 images)
   - **Why**: Environment-specific retention for cost management

6. **ecr_lifecycle_policy_prod_retention**
   - Validates policy uses `prod-` tag prefix
   - Confirms retention count matches prod configuration (e.g., 20 images)
   - **Why**: Deeper rollback history for production

7. **ecr_variable_validation_retention_count**
   - Tests valid retention counts are accepted
   - **Why**: Input validation

8. **ecr_variable_validation_environment**
   - Tests valid environment values are accepted (prod)
   - **Why**: Environment validation

---

#### 6.3.3. ecs_cluster.tftest.hcl

**Module Tested**: `modules/ecs_cluster/` <br>
**Purpose**: Validates ECS cluster, Auto Scaling Group, Launch Template, and IAM configuration.

**Data Overrides**: Tests use `override_data` blocks to mock SSM parameter and AMI data sources (avoids real AWS API calls).

**Test Suites**:

1. **ecs_cluster_basic_configuration**
   - Verifies ECS cluster naming: `${environment}-${project_name}-ecs-cluster`
   - **Why**: Naming consistency

2. **ecs_asg_configuration**
   - Validates ASG min and max size match configured values
   - Confirms EC2 health check type with 300s grace period
   - Checks scale-in protection is disabled for dev
   - Validates ASG is deployed in all private subnets
   - Confirms `AmazonECSManaged` tag is present
   - **Why**: This tag is critical for Capacity Provider integration

3. **ecs_asg_production_configuration**
   - Confirms scale-in protection is enabled for prod
   - **Why**: Protects running tasks from premature termination

4. **ecs_launch_template_configuration**
   - Validates instance type matches configuration
   - Confirms ECS-optimized AMI is used
   - Checks IMDSv2 is required (`http_tokens = "required"`)
   - **Why**: Enhanced security for instance metadata access
   - Validates IMDS endpoint is enabled
   - Confirms IAM instance profile and security group are attached

5. **ecs_security_group_configuration**
   - Validates security group is in correct VPC
   - Confirms egress rule allows all protocols
   - **Why**: Instances need outbound access for ECS Agent, image pulls, patching

6. **ecs_iam_configuration**
   - Validates IAM role and instance profile are created
   - Confirms EC2 policy is attached
   - Validates SSM managed policy is attached
   - **Why**: Enables Systems Manager Session Manager access

7. **ecs_tags_applied**
   - Validates Project and Environment tags are applied to ASG
   - **Why**: Resource organization and cost allocation

---

#### 6.3.4. ecs_service.tftest.hcl

**Module Tested**: `modules/ecs_service/` <br>
**Purpose**: Validates ECS task definition, service configuration, auto-scaling, and security.

**Test Suites**:

1. **ecs_service_basic_configuration**
   - Verifies ECS service naming: `${environment}-${project_name}-ecs-service`
   - Validates desired count matches input
   - Confirms capacity provider strategy is configured
   - **Why**: Ensures service uses Capacity Provider for EC2 scaling

2. **ecs_task_definition_configuration**
   - Validates task definition family matches container name
   - Confirms CPU and memory limits match configuration
   - Checks network mode is `awsvpc`
   - **Why**: Required for awsvpc networking mode and ENI assignment
   - Validates container definitions include correct ECR image
   - Confirms correct container port is exposed
   - **Why**: Regex validation ensures image and port are in JSON definition

3. **ecs_service_deployment_configuration**
   - Validates minimum healthy percent (50%)
   - Confirms maximum percent (200%)
   - **Why**: Allows rolling updates with temporary over/under-provisioning

4. **ecs_service_load_balancer_integration**
   - Confirms load balancer configuration exists
   - **Why**: Ensures ALB integration for traffic distribution

5. **ecs_service_security_group**
   - Validates security group is in correct VPC
   - Confirms security group has a name
   - **Why**: Basic security group creation check

6. **ecs_cloudwatch_logs**
   - Validates CloudWatch log group matches configuration
   - **Why**: Ensures application logs are written to correct location

7. **ecs_iam_roles**
   - Confirms task execution role is created
   - Validates trust relationship includes `ecs-tasks.amazonaws.com`
   - **Why**: Allows ECS service to assume role for image pull and logging

---

#### 6.3.5. ssl.tftest.hcl

**Module Tested**: `modules/ssl/` <br>
**Purpose**: Validates ACM certificate configuration, DNS validation, SANs, and lifecycle rules.

**Test Suites**:

1. **ssl_certificate_basic_configuration**
   - Verifies certificate domain matches root domain
   - Confirms DNS validation method (not email)
   - **Why**: DNS validation enables automation
   - Validates wildcard SAN is included

2. **ssl_validation_records_configuration**
   - Confirms all validation records use correct hosted zone ID
   - Validates `allow_overwrite = true` for redeployments
   - Checks TTL is 60 seconds
   - **Why**: Fast DNS propagation for validation

3. **ssl_certificate_validation_configuration**
   - Validates validation records are created
   - **Why**: Ensures validation workflow can complete

4. **ssl_production_environment**
   - Tests production certificate has correct domain
   - **Why**: Environment-specific validation

5. **ssl_san_wildcard_coverage**
   - Validates root domain is primary certificate domain
   - Confirms wildcard SAN covers all subdomains
   - **Why**: Single certificate for root and all subdomains

6. **ssl_validation_method_dns_only**
   - Confirms DNS validation is used (critical for automation)
   - Ensures email validation is NOT used
   - **Why**: Email validation requires manual intervention

---

## 7. Project Structure

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
