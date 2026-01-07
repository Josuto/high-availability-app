# EKS Infrastructure Documentation

This directory contains the complete Terraform infrastructure for deploying a high-availability NestJS application using AWS Elastic Kubernetes Service (EKS). The implementation follows Infrastructure as Code (IaC) principles with modular, reusable components and leverages Kubernetes for container orchestration.

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
   - [3.3. Application Deployment Infrastructure (EKS-Specific)](#33-application-deployment-infrastructure-eks-specific)
     - [3.3.1. Virtual Private Cloud (VPC)](#331-virtual-private-cloud-vpc)
     - [3.3.2. EKS Cluster](#332-eks-cluster)
     - [3.3.3. EKS Node Group](#333-eks-node-group)
     - [3.3.4. AWS Load Balancer Controller](#334-aws-load-balancer-controller)
     - [3.3.5. Kubernetes Application Deployment](#335-kubernetes-application-deployment)
     - [3.3.6. Routing](#336-routing)
     - [3.3.7. IAM Roles and Policies](#337-iam-roles-and-policies)
4. [Environment Configuration Differences](#4-environment-configuration-differences)
5. [CI/CD Workflows](#5-cicd-workflows)
   - [5.1. Initial Setup](#51-initial-setup)
   - [5.2. Full Infrastructure Deployment](#52-full-infrastructure-deployment)
   - [5.3. Infrastructure Teardown](#53-infrastructure-teardown)
6. [Terraform Testing](#6-terraform-testing)
   - [6.1. Running Tests](#61-running-tests)
   - [6.2. Test Files Explained](#62-test-files-explained)
7. [Project Structure](#7-project-structure)

---

## 1. High-Level Overview

The EKS infrastructure implements a production-ready, highly available Kubernetes platform on AWS. The architecture leverages managed Kubernetes services (EKS), AWS Load Balancer Controller for native ALB integration, and Horizontal Pod Autoscaling for dynamic workload management.

### Key Components and Their Relationships

```
Internet
    ↓
[Route 53] → Points to ALB DNS (created by Ingress)
    ↓
[Application Load Balancer] ← Created by AWS Load Balancer Controller
    ↓ (HTTPS:443 / HTTP:80→HTTPS)
[Kubernetes Service] ← ClusterIP, load balanced internally
    ↓
[Kubernetes Pods] (running containers)
    ↓ Scheduled on
[EC2 Worker Nodes] (in private subnets)
    ↓ Managed by
[EKS Node Group with Auto Scaling]
    ↓ Part of
[EKS Cluster] (Managed Kubernetes Control Plane)
```

### Traffic Flow

1. **Inbound Traffic**: User requests hit Route 53 → ALB (validates SSL certificate) → Kubernetes Ingress → Kubernetes Service → Pods on worker nodes
2. **Outbound Traffic**: Pods → NAT Gateway (in public subnets) → Internet Gateway → Internet

### Core Design Principles

- **High Availability**: Multi-AZ deployment for both control plane and worker nodes
- **Security**: Private subnets for compute, security groups with least-privilege access, IAM roles for service accounts (IRSA)
- **Scalability**: Cluster Autoscaler for worker nodes, Horizontal Pod Autoscaler (HPA) for pods
- **Kubernetes-Native**: Ingress resources for ALB management, native Kubernetes service discovery and load balancing
- **Modularity**: Reusable Terraform modules following Single Responsibility Principle
- **Environment Flexibility**: Configuration-driven differences between dev and prod environments

### EKS vs ECS Key Differences

| Aspect | EKS (This Implementation) | ECS (Alternative) |
|--------|---------------------------|-------------------|
| **Orchestration** | Kubernetes (open-source, portable) | AWS ECS (AWS-specific) |
| **Control Plane** | Managed by AWS EKS | Managed by AWS ECS |
| **Load Balancing** | AWS Load Balancer Controller (via Ingress) | ALB directly managed by Terraform |
| **Scaling** | Horizontal Pod Autoscaler (HPA) + Cluster Autoscaler | ECS Service auto-scaling + Capacity Provider |
| **Workload Definition** | Deployment + Service + Ingress | Task Definition + Service |
| **Networking** | Kubernetes CNI (AWS VPC CNI) | awsvpc mode with ENI per task |

---

## 2. Prerequisites and First-Time Setup

Before deploying this infrastructure, you need to configure several variables and files with your own values. This section guides you through all required configuration changes.

### 2.1. Prerequisites

Ensure you have the following before starting:

- **AWS Account** with appropriate IAM permissions to create VPC, EKS, ALB, Route53, ACM, ECR, and IAM resources
- **Domain Name** registered at any domain registrar (e.g., GoDaddy, Namecheap, Route53)
- **Terraform 1.0+** installed locally ([Installation Guide](https://developer.hashicorp.com/terraform/downloads))
- **AWS CLI** installed and configured ([Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **kubectl** installed for Kubernetes cluster management ([Installation Guide](https://kubernetes.io/docs/tasks/tools/))
- **(Optional) Helm CLI** for package management ([Installation Guide](https://helm.sh/docs/intro/install/))
- **(Optional) GitHub Repository** if you plan to use the included CI/CD workflows
- **(Optional) Pre-commit Tools** for local development: TFLint, tfsec, detect-secrets, terraform-docs

### 2.2. Required Configuration Changes

You must update the following configuration files before deployment. All files are located in `infra-eks/deployment/`.

#### Step 1: Configure S3 Backend for Terraform State

Update **both files** with your unique S3 bucket name:

**File 1:** `infra-eks/deployment/backend.tfvars`
```hcl
# S3 bucket name for Terraform state storage
state_bucket_name = "your-unique-bucket-name"
```

**File 2:** `infra-eks/deployment/backend-config.hcl`
```hcl
# Must match the value in backend.tfvars
bucket = "your-unique-bucket-name"

# Optional: Uncomment if you enable DynamoDB state locking
# dynamodb_table = "your-terraform-locks-table"
```

**Critical**: Both values **must match** exactly. The bucket name must be globally unique across all AWS accounts.

**Example:**
```hcl
state_bucket_name = "mycompany-terraform-state-bucket-eks"
bucket = "mycompany-terraform-state-bucket-eks"
```

---

#### Step 2: Configure Project Name and Environment

Edit `infra-eks/deployment/common.tfvars`:

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
- EKS Cluster: `${environment}-${project_name}-eks-cluster` → `prod-myapp-eks-cluster`
- Node Group: `${environment}-${project_name}-node-group` → `prod-myapp-node-group`
- ECR Repository: `${environment}-${project_name}-ecr-repository` → `prod-myapp-ecr-repository`

---

#### Step 3: Configure Your Domain Name

Edit `infra-eks/deployment/domain.tfvars`:

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
- Route 53 A records will be created for: `example.com` (pointing to ALB created by Ingress)

---

#### Step 4: (Optional) Change AWS Region

By default, the infrastructure deploys to `eu-west-1`. To use a different region:

**A. Update GitHub Workflows** (if using CI/CD):

Edit `.github/workflows/eks/*.yaml` files:
```yaml
env:
  AWS_REGION: your-preferred-region  # Change from eu-west-1
  TERRAFORM_VERSION: 1.10.3
  KUBECTL_VERSION: 1.28.0
  HELM_VERSION: 3.13.0
```

**B. Update Backend Configuration:**

Edit `infra-eks/deployment/backend-config.hcl` and add the region parameter:
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
The IAM user needs permissions for: VPC, EC2, EKS, ECR, ALB, Route53, ACM, IAM, CloudWatch, Auto Scaling, S3 (for state), and optionally DynamoDB (for locking).

**Security Best Practice:** Create a dedicated IAM user for CI/CD with least-privilege permissions.

---

### 2.3. Environment-Specific Configuration (Optional)

The infrastructure supports different resource configurations for `dev` and `prod` environments through configuration maps defined in `common.tfvars` and module-specific tfvars files.

**Default Configuration:**
The repository includes sensible defaults for both environments. For most use cases, you **do not need to modify** these values.

**Advanced Configuration:**
If you want to customize environment-specific settings (e.g., instance sizes, scaling limits, NAT gateway configuration, capacity types), refer to [Section 4: Environment Configuration Differences](#4-environment-configuration-differences) for a complete explanation of all available settings.

**Example Settings:**
- NAT Gateway count (single vs multi-AZ)
- ECR image retention (3 images in dev, 10 in prod)
- Node Group min/max instances
- Worker node capacity type (SPOT vs ON_DEMAND)
- Pod replica counts and resource limits

---

### 2.4. DNS Configuration (Post-Deployment)

After deploying the Route 53 Hosted Zone (see [Section 5.1: Initial Setup](#51-initial-setup)), you must **manually update DNS nameservers** at your domain registrar.

**Steps:**

1. **Deploy the Hosted Zone** using the `eks-deploy-hosted-zone.yaml` workflow or Terraform

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

#### Child Modules (`infra-eks/modules/*`)

Child modules are **single-purpose, reusable infrastructure components** that define specific AWS resources:
- Examples: `ecr`, `eks_cluster`, `eks_node_group`, `aws_lb_controller`, `k8s_app`, `ssl`, `hosted_zone`, `routing`
- Accept inputs via variables (e.g., `var.vpc_id`, `var.project_name`)
- Return outputs (e.g., `cluster_id`, `cluster_oidc_issuer_url`)
- **No knowledge** of other modules or deployment stages
- **No remote state references** - completely self-contained
- Designed for maximum portability and reusability across projects

#### Root Modules (`infra-eks/deployment/*`)

Root modules are **environment-specific orchestration layers** that:
- Stitch child modules together to create complete infrastructure stages
- Use `data "terraform_remote_state"` to read outputs from previous deployment stages
- Pass environment-specific configuration to child modules
- Examples: `deployment/app/vpc`, `deployment/app/eks_cluster`, `deployment/app/eks_node_group`

#### How They Work Together

**Example: EKS Node Group depends on outputs from VPC and EKS Cluster**

The `deployment/app/eks_node_group/` root module:
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

2. Reads EKS cluster outputs from `deployment/app/eks_cluster/` remote state:
   ```hcl
   data "terraform_remote_state" "eks_cluster" {
     backend = "s3"
     config = {
       bucket = "terraform-state-bucket"
       key    = "deployment/app/eks_cluster/terraform.tfstate"
       region = "eu-west-1"
     }
   }
   ```

3. Passes these values to the `eks_node_group` child module:
   ```hcl
   module "eks_node_group" {
     source = "../../../modules/eks_node_group"

     eks_cluster_name    = data.terraform_remote_state.eks_cluster.outputs.cluster_id
     vpc_private_subnets = data.terraform_remote_state.vpc.outputs.vpc_private_subnets
   }
   ```

**Deployment Order and Dependencies**

The deployment stages must be executed in dependency order:
1. `backend/` → Creates S3 state bucket (no dependencies)
2. `hosted_zone/` → Creates Route53 zone (no dependencies)
3. `ssl/` → Requires outputs from `hosted_zone/` (reads hosted_zone_id)
4. `ecr/` → Creates ECR repository (no dependencies)
5. `app/vpc/` → Creates network infrastructure with EKS-specific tags (no dependencies)
6. `app/eks_cluster/` → Requires outputs from `vpc/` (reads vpc_id, private_subnets, public_subnets)
7. `app/eks_node_group/` → Requires outputs from `vpc/` and `eks_cluster/` (reads cluster_name, private_subnets)
8. `app/aws_lb_controller/` → Requires outputs from `eks_cluster/` and `vpc/` (reads cluster_id, OIDC issuer)
9. `app/k8s_app/` → Requires outputs from `ecr/`, `eks_cluster/`, and `ssl/` (reads repository URL, certificate ARN)
10. `app/routing/` → Requires outputs from `hosted_zone/` and `k8s_app/` (reads zone_id, ALB hostname from Ingress)

**Why This Architecture?**

- **Reusability**: The `eks_cluster` child module can be used in any project that needs an EKS cluster, without copying VPC or node group code
- **Separation of Concerns**: Each child module has a single responsibility (e.g., EKS cluster module only manages the cluster control plane)
- **Staged Deployment**: Root modules enable deploying infrastructure in logical stages with clear dependencies
- **Environment Isolation**: Different environments (dev, prod) use the same child modules with different configuration values
- **State Isolation**: Each deployment stage has its own Terraform state file, reducing blast radius of changes

---

### 3.2. Foundational Infrastructure (Approach-Agnostic)

These root modules represent **approach-agnostic infrastructure** - components that are shared between different container orchestration approaches (ECS and EKS implementations). They reside directly under `infra-eks/deployment/` and provide foundational services required by any application deployment.

**Approach-Agnostic Modules:**
- **`backend/`**: S3 bucket for Terraform remote state storage
- **`ecr/`**: Docker container registry (see [Section 3.2.1](#321-elastic-container-registry-ecr))
- **`ssl/`**: ACM SSL certificate for HTTPS (see [Section 3.2.2](#322-ssl-certificate-acm))
- **`hosted_zone/`**: Route53 hosted zone for DNS management (see [Section 3.2.3](#323-route-53))

**Key Characteristic:** These modules are not specific to EKS - the same modules are also used in the ECS implementation (`infra-ecs/`), providing shared infrastructure across both approaches.

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
**Module Location**: `infra-eks/modules/ecr/` <br>
**Deployment Location**: `infra-eks/deployment/ecr/`

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
4. Validated certificate ARN becomes available for Ingress attachment

**Module Location**: `infra-eks/modules/ssl/` <br>
**Deployment Location**: `infra-eks/deployment/ssl/`

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

**Module Location**: `infra-eks/modules/hosted_zone/` <br>
**Deployment Location**: `infra-eks/deployment/hosted_zone/`

**Note**: DNS records (A records) that point to the Application Load Balancer are created by the approach-specific routing module (see [Section 3.3.6](#336-routing)).

---

### 3.3. Application Deployment Infrastructure (EKS-Specific)

These root modules represent **EKS-specific application infrastructure** - components that are unique to the Kubernetes-based container orchestration approach. They reside under `infra-eks/deployment/app/` and implement the compute, networking, and load balancing layers specific to running containers on EKS.

**EKS-Specific Modules:**
- **`app/vpc/`**: Network infrastructure with EKS-specific subnet tags (see [Section 3.3.1](#331-virtual-private-cloud-vpc))
- **`app/eks_cluster/`**: Managed Kubernetes control plane (see [Section 3.3.2](#332-eks-cluster))
- **`app/eks_node_group/`**: Worker nodes with Auto Scaling (see [Section 3.3.3](#333-eks-node-group))
- **`app/aws_lb_controller/`**: Helm chart for ALB management via Ingress (see [Section 3.3.4](#334-aws-load-balancer-controller))
- **`app/k8s_app/`**: Kubernetes Deployment, Service, Ingress, HPA (see [Section 3.3.5](#335-kubernetes-application-deployment))
- **`app/routing/`**: Route 53 A records pointing to ALB created by Ingress (see [Section 3.3.6](#336-routing))

**Key Characteristic:** These modules implement Kubernetes-specific concepts (clusters, node groups, pods, ingress controllers) and would be replaced by different modules in the ECS implementation (ECS clusters, services, tasks).

The following subsections provide detailed explanations of each infrastructure component, organized by category.

---

#### 3.3.1. Virtual Private Cloud (VPC)

**Purpose**: Provides isolated network infrastructure for all AWS resources with EKS-specific subnet tagging.

**Key Features**:
- **Multi-AZ Architecture**: Spans multiple Availability Zones for fault tolerance
- **Subnet Strategy**:
  - **Public Subnets**: Host NAT Gateways and Application Load Balancer (created by Ingress)
  - **Private Subnets**: Host EKS worker nodes, isolated from direct internet access
- **NAT Gateway**: Enables outbound internet connectivity for resources in private subnets (e.g., pulling Docker images, accessing AWS services)
- **Internet Gateway**: Provides internet access to resources in public subnets
- **EKS-Specific Subnet Tags**: Required for AWS Load Balancer Controller and Kubernetes to discover subnets
  - Public subnets: `kubernetes.io/role/elb = 1`
  - Private subnets: `kubernetes.io/role/internal-elb = 1`
  - Both: `kubernetes.io/cluster/${cluster_name} = shared`

**Environment Differences**:
| Setting | dev | prod | Rationale |
|---------|-----|------|-----------|
| NAT Gateway | Single (single_nat_gateway = true) | Multiple (one per AZ) | Cost savings vs high availability |

**Module Location**: Uses the official `terraform-aws-modules/vpc/aws` module <br>
**Deployment Location**: `infra-eks/deployment/app/vpc/`

**Critical Tags Configuration**:
```hcl
public_subnet_tags = {
  "kubernetes.io/role/elb"                    = "1"
  "kubernetes.io/cluster/${cluster_name}"     = "shared"
}

private_subnet_tags = {
  "kubernetes.io/role/internal-elb"           = "1"
  "kubernetes.io/cluster/${cluster_name}"     = "shared"
}
```

---

#### 3.3.2. EKS Cluster

**Purpose**: Provides the managed Kubernetes control plane (API server, etcd, scheduler, controller manager).

**Key Components**:

#### a) EKS Cluster Resource
- **Managed Control Plane**: AWS manages the Kubernetes control plane components across multiple AZs
- **API Endpoint**: Can be public, private, or both (default: public for easier access during development)
- **Kubernetes Version**: Configurable (default: latest stable version)
- **Logging**: Optional CloudWatch logging for audit, API, authenticator, controller manager, and scheduler logs

#### b) Cluster IAM Role
- **Cluster Service Role**: Allows EKS to manage AWS resources on your behalf
- **Managed Policies**:
  - `AmazonEKSClusterPolicy`: Core permissions for EKS cluster operation
  - `AmazonEKSVPCResourceController`: Enables security group management for pods

#### c) OIDC Provider
- **IAM Roles for Service Accounts (IRSA)**: Enables Kubernetes service accounts to assume IAM roles
- **Purpose**: Allows pods to access AWS services without storing credentials
- **Use Cases**: AWS Load Balancer Controller, external-dns, cluster-autoscaler, application pods needing AWS API access

#### d) Cluster Security Group
- **Default Security Group**: Allows communication between control plane and worker nodes
- **Ingress**: Port 443 from worker nodes (for kubectl commands)
- **Egress**: Ports 1025-65535 to worker nodes (for control plane to node communication)

**Key Configuration**:
```hcl
endpoint_public_access = true  # API server accessible from internet
endpoint_private_access = true # API server accessible from VPC
```

**Naming Convention**: `${environment}-${project_name}-eks-cluster` <br>
**Module Location**: `infra-eks/modules/eks_cluster/` <br>
**Deployment Location**: `infra-eks/deployment/app/eks_cluster/`

---

#### 3.3.3. EKS Node Group

**Purpose**: Manages the EC2 worker nodes that run Kubernetes pods.

**Key Components**:

#### a) Managed Node Group
- **Lifecycle Management**: AWS manages node provisioning, updates, and termination
- **Auto Scaling**: Automatically adjusts the number of nodes based on pod resource requests
- **Health Checks**: Unhealthy nodes are automatically replaced
- **Update Strategy**: Rolling updates with configurable max unavailable nodes

#### b) Launch Template
- **AMI**: Uses EKS-optimized Amazon Linux 2 AMI (automatically selected by EKS)
- **Instance Type**: Configurable per environment (t3.small for dev, t3.medium for prod)
- **Disk Size**: Configurable per environment (20GB for dev, 40GB for prod)
- **User Data**: Automatically configured by EKS to join the cluster

#### c) Capacity Type
- **ON_DEMAND**: Standard EC2 instances with guaranteed availability (prod default)
- **SPOT**: Spare EC2 capacity at significant cost savings, can be interrupted (dev default)

#### d) Node IAM Role
- **Node Instance Role**: Allows EC2 instances to interact with EKS, ECR, and other AWS services
- **Managed Policies**:
  - `AmazonEKSWorkerNodePolicy`: Core permissions for EKS worker nodes
  - `AmazonEKS_CNI_Policy`: Enables AWS VPC CNI plugin to manage pod networking
  - `AmazonEC2ContainerRegistryReadOnly`: Allows pulling images from ECR
  - `AmazonSSMManagedInstanceCore`: Enables Systems Manager Session Manager access

**Environment Differences**:
| Setting | dev | prod | Rationale |
|---------|-----|------|-----------|
| Instance Type | t3.small | t3.medium | Cost vs performance |
| Min/Max Nodes | 1/5 | 2/10 | Cost vs baseline capacity |
| Desired Count | 2 | 3 | Minimum for HA |
| Capacity Type | SPOT | ON_DEMAND | Cost savings vs reliability |
| Disk Size | 20GB | 40GB | Storage cost vs container image cache |

**Naming Convention**: `${environment}-${project_name}-node-group` <br>
**Module Location**: `infra-eks/modules/eks_node_group/` <br>
**Deployment Location**: `infra-eks/deployment/app/eks_node_group/`

---

#### 3.3.4. AWS Load Balancer Controller

**Purpose**: Kubernetes controller that manages AWS Application Load Balancers via Ingress resources.

**Key Components**:

#### a) Helm Chart Deployment
- **Chart**: `aws-load-balancer-controller` from the official AWS EKS charts repository
- **Version**: Configurable (default: latest stable)
- **Namespace**: `kube-system` (standard namespace for cluster add-ons)
- **Values Configuration**:
  - Cluster name for resource tagging
  - AWS region for API calls
  - VPC ID for security group management
  - Service account with IRSA annotation

#### b) IAM Role for Service Account (IRSA)
- **Purpose**: Allows the controller to create and manage ALB resources
- **Permissions**: Create/delete ALBs, target groups, listeners, security groups, and rules
- **Trust Policy**: Assumes role via OIDC provider
- **Service Account Annotation**: `eks.amazonaws.com/role-arn: ${controller_role_arn}`

#### c) Controller Functionality
- **Ingress to ALB**: Automatically creates ALB when Ingress resource is created
- **Service to Target Group**: Creates target groups and registers pod IPs
- **Annotations**: Supports extensive ALB configuration via Kubernetes annotations
- **Health Checks**: Configures ALB health checks based on readiness probes

**How It Works**:
1. User creates Kubernetes Ingress resource with appropriate annotations
2. AWS Load Balancer Controller watches for Ingress changes
3. Controller creates ALB, listeners, target groups, and security groups in AWS
4. Controller continuously syncs Kubernetes state with AWS resources
5. When Ingress is deleted, controller cleans up AWS resources

**Module Location**: `infra-eks/modules/aws_lb_controller/` <br>
**Deployment Location**: `infra-eks/deployment/app/aws_lb_controller/`

---

#### 3.3.5. Kubernetes Application Deployment

**Purpose**: Deploys the containerized application using native Kubernetes resources.

**Key Components**:

#### a) Kubernetes Deployment
- **Purpose**: Manages pod replicas, rolling updates, and rollbacks
- **Replica Count**: Configurable per environment (2 for dev, 3 for prod)
- **Container Specification**:
  - **Image**: Pulled from ECR repository
  - **Port**: Exposes container port (default: 3000)
  - **Resource Requests/Limits**: CPU and memory per environment
  - **Liveness Probe**: HTTP GET to `/health` endpoint
  - **Readiness Probe**: HTTP GET to `/health` endpoint (determines pod traffic eligibility)
- **Update Strategy**: RollingUpdate with configurable max surge and max unavailable

#### b) Kubernetes Service
- **Type**: ClusterIP (internal load balancing)
- **Purpose**: Provides stable internal DNS name and load balances traffic across pods
- **Selector**: Matches pods by label (e.g., `app: nestjs-app`)
- **Port Mapping**: Service port (80) → Target port (3000)
- **Session Affinity**: Optional sticky sessions (ClientIP-based)

#### c) Kubernetes Ingress
- **Purpose**: Exposes HTTP/HTTPS routes from outside the cluster to the Service
- **Ingress Class**: `alb` (triggers AWS Load Balancer Controller)
- **Annotations**:
  - `alb.ingress.kubernetes.io/scheme: internet-facing` (public ALB)
  - `alb.ingress.kubernetes.io/target-type: ip` (register pod IPs directly)
  - `alb.ingress.kubernetes.io/certificate-arn: ${acm_cert_arn}` (SSL certificate)
  - `alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'`
  - `alb.ingress.kubernetes.io/ssl-redirect: '443'` (redirect HTTP to HTTPS)
- **Rules**: Routes all traffic to the Service

#### d) Horizontal Pod Autoscaler (HPA)
- **Purpose**: Automatically scales pod replicas based on resource utilization
- **Metrics**:
  - **CPU**: Target 70% utilization (configurable)
  - **Memory**: Target 80% utilization (configurable)
- **Scaling Behavior**:
  - **Scale-Up**: Aggressive (add pods quickly when load increases)
  - **Scale-Down**: Conservative (wait 5 minutes before removing pods)
- **Min/Max Replicas**: Configurable per environment (2-5 for dev, 3-10 for prod)

**Environment Differences**:
| Setting | dev | prod | Rationale |
|---------|-----|------|-----------|
| Replicas | 2 | 3 | Cost vs baseline availability |
| CPU Request | 50m | 250m | Resource allocation |
| CPU Limit | 250m | 500m | Burst capacity |
| Memory Request | 128Mi | 512Mi | Baseline memory |
| Memory Limit | 512Mi | 1024Mi | Maximum memory |
| HPA Min | 2 | 3 | Minimum replicas |
| HPA Max | 5 | 10 | Maximum replicas |

**Module Location**: `infra-eks/modules/k8s_app/` <br>
**Deployment Location**: `infra-eks/deployment/app/k8s_app/`

**Resource Manifest Overview**:
```yaml
# Deployment (managed by Terraform via kubernetes provider)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nestjs-app-deployment
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: nestjs-app
        image: <ECR_IMAGE>
        ports:
        - containerPort: 3000
        resources:
          requests:
            cpu: 250m
            memory: 512Mi
          limits:
            cpu: 500m
            memory: 1024Mi

# Service
apiVersion: v1
kind: Service
metadata:
  name: nestjs-app-service
spec:
  type: ClusterIP
  selector:
    app: nestjs-app
  ports:
  - port: 80
    targetPort: 3000

# Ingress (triggers ALB creation)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nestjs-app-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/certificate-arn: <ACM_CERT_ARN>
spec:
  ingressClassName: alb
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nestjs-app-service
            port:
              number: 80
```

---

#### 3.3.6. Routing

**Purpose**: Creates DNS records (A records) that route traffic from the domain to the Application Load Balancer created by the Kubernetes Ingress.

**Key Features**:
- **Root Domain**: Points to ALB (e.g., `example.com` → ALB DNS created by Ingress)
- **Record Type**: A record with alias to ALB
- **Evaluate Target Health**: Enabled (Route 53 checks ALB health)
- **Data Source**: ALB hostname and zone ID are read from Kubernetes Ingress resource outputs via remote state

**Dependencies**:
- **hosted_zone**: Requires hosted zone ID from foundational infrastructure
- **k8s_app**: Requires ALB hostname and zone ID from Kubernetes Ingress status (EKS-specific)

**Why This Is EKS-Specific**:
The routing module depends on outputs from the `k8s_app` deployment, specifically the ALB hostname created dynamically by the AWS Load Balancer Controller when the Ingress resource is deployed. In the ECS implementation, routing depends on the ALB created directly by Terraform, making each routing implementation approach-specific.

**Module Location**: `infra-eks/modules/routing/` <br>
**Deployment Location**: `infra-eks/deployment/app/routing/`

---

#### 3.3.7. IAM Roles and Policies

The infrastructure uses multiple IAM roles for different levels of authorization in the EKS ecosystem.

#### a) EKS Cluster Service Role

**Assumed By**: EKS service principal (`eks.amazonaws.com`)

**Purpose**: Allows EKS to manage AWS resources on behalf of the cluster.

**Managed Policies Attached**:
1. **AmazonEKSClusterPolicy** (`arn:aws:iam::aws:policy/AmazonEKSClusterPolicy`)
   - Core permissions for EKS cluster operation
   - Permissions: Create/manage ENIs, security groups, EC2 instances for the cluster

2. **AmazonEKSVPCResourceController** (`arn:aws:iam::aws:policy/AmazonEKSVPCResourceController`)
   - Enables security group management for pods using security group per pod feature
   - Permissions: Manage ENI and security group attachments

**Module Location**: `infra-eks/modules/eks_cluster/iam.tf`

---

#### b) EKS Node IAM Role

**Assumed By**: EC2 service principal (`ec2.amazonaws.com`)

**Purpose**: Allows worker nodes to interact with EKS, ECR, and other AWS services.

**Managed Policies Attached**:
1. **AmazonEKSWorkerNodePolicy** (`arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy`)
   - Allows nodes to connect to EKS cluster
   - Permissions: `eks:DescribeCluster`

2. **AmazonEKS_CNI_Policy** (`arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy`)
   - Enables AWS VPC CNI plugin to manage pod networking
   - Permissions: Create/attach/delete ENIs, assign IP addresses

3. **AmazonEC2ContainerRegistryReadOnly** (`arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly`)
   - Allows pulling container images from ECR
   - Permissions: `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:GetDownloadUrlForLayer`, `ecr:BatchGetImage`

4. **AmazonSSMManagedInstanceCore** (`arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore`)
   - Enables Systems Manager Session Manager for secure shell access
   - Eliminates need for SSH keys and bastion hosts

**Module Location**: `infra-eks/modules/eks_node_group/iam.tf`

---

#### c) AWS Load Balancer Controller IAM Role (IRSA)

**Assumed By**: Kubernetes service account via OIDC provider

**Purpose**: Allows AWS Load Balancer Controller to manage ALB resources.

**Custom Inline Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:CreateTargetGroup",
        "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:CreateRule",
        "elasticloadbalancing:DeleteRule",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets",
        "ec2:DescribeSecurityGroups",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress"
      ],
      "Resource": "*"
    }
  ]
}
```

**Trust Policy** (IRSA-specific):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${account_id}:oidc-provider/${oidc_provider}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${oidc_provider}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }
  ]
}
```

**Service Account Annotation**:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::${account_id}:role/${controller_role_name}
```

**Module Location**: `infra-eks/modules/aws_lb_controller/iam.tf`

---

## 4. Environment Configuration Differences

The infrastructure supports two environments (`dev` and `prod`) with configuration-driven differences to balance cost, performance, and reliability.

| Component | Setting | dev | prod | Rationale |
|-----------|---------|-----|------|-----------|
| **VPC** | NAT Gateway | Single (single_nat_gateway = true) | Multiple (one per AZ) | Cost savings in dev; high availability in prod |
| **ECR** | Tagged Image Retention | 3 images | 10 images | Minimal storage in dev; deeper rollback history in prod |
| **EKS Node Group** | Instance Type | t3.small | t3.medium | Lower cost in dev; more capacity in prod |
| **EKS Node Group** | Min Nodes | 1 | 2 | Lower baseline cost in dev; always-on capacity in prod |
| **EKS Node Group** | Max Nodes | 5 | 10 | Limited scaling in dev; room for growth in prod |
| **EKS Node Group** | Desired Count | 2 | 3 | Minimum for HA in dev; baseline capacity in prod |
| **EKS Node Group** | Capacity Type | SPOT | ON_DEMAND | Cost savings in dev; reliability in prod |
| **EKS Node Group** | Disk Size | 20GB | 40GB | Minimal storage in dev; more cache in prod |
| **K8s Deployment** | Replicas | 2 | 3 | Lower baseline in dev; HA in prod |
| **K8s Deployment** | CPU Request | 50m | 250m | Minimal resources in dev; proper allocation in prod |
| **K8s Deployment** | CPU Limit | 250m | 500m | Lower ceiling in dev; more burst capacity in prod |
| **K8s Deployment** | Memory Request | 128Mi | 512Mi | Minimal memory in dev; proper allocation in prod |
| **K8s Deployment** | Memory Limit | 512Mi | 1024Mi | Lower ceiling in dev; more headroom in prod |
| **HPA** | Min Replicas | 2 | 3 | Lower baseline in dev; HA in prod |
| **HPA** | Max Replicas | 5 | 10 | Limited scaling in dev; more capacity in prod |
| **Route 53** | force_destroy | true | false | Allow cleanup in dev; protect domain in prod |

**Configuration Files**:
- `infra-eks/deployment/common.tfvars` - Common variables
- `infra-eks/deployment/app/eks_node_group/vars.tf` - Node group defaults
- `infra-eks/deployment/app/k8s_app/vars.tf` - Application defaults

Example from `common.tfvars`:
```hcl
environment  = "prod"
project_name = "myapp"

# VPC Configuration
single_nat_gateway = {
  dev  = true
  prod = false
}

# ECR Configuration
image_retention_max_count = {
  dev  = 3
  prod = 10
}
```

Example from `eks_node_group/vars.tf`:
```hcl
variable "instance_type" {
  type = map(string)
  default = {
    dev  = "t3.small"
    prod = "t3.medium"
  }
}

variable "capacity_type" {
  type = map(string)
  default = {
    dev  = "SPOT"
    prod = "ON_DEMAND"
  }
}
```

---

## 5. CI/CD Workflows

All infrastructure deployment and teardown is managed through GitHub Actions workflows located in `.github/workflows/eks/`. These workflows automate Terraform operations in a dependency-aware order.

### Workflow Overview

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

### 5.1. Initial Setup

**Workflow**: `eks-deploy-hosted-zone.yaml`
**Trigger**: Manual (`workflow_dispatch`)
**Purpose**: One-time setup of foundational infrastructure

#### Jobs Sequence

1. **deploy-terraform-state-bucket**
   - Creates S3 bucket for Terraform remote state storage
   - Enables versioning for state file history
   - **Reusable Workflow**: Calls `eks_deploy_terraform_state_bucket.yaml`

2. **deploy-hosted-zone** (depends on: deploy-terraform-state-bucket)
   - Creates Route 53 Hosted Zone for the domain
   - Initializes Terraform with remote state backend
   - Runs `terraform plan` and `terraform apply` in `infra-eks/deployment/hosted_zone/`
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

**Workflow**: `eks-deploy-aws-infra.yaml`
**Trigger**: Push to `main` branch
**Purpose**: Complete infrastructure deployment from ECR to running Kubernetes application

#### Jobs Sequence

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

#### Workflow Environment Variables

```yaml
env:
  AWS_REGION: eu-west-1
  TERRAFORM_VERSION: 1.10.3
  KUBECTL_VERSION: 1.28.0
  HELM_VERSION: 3.13.0
```

#### Secrets Required

- `AWS_ACCESS_KEY_ID`: AWS IAM user access key
- `AWS_SECRET_ACCESS_KEY`: AWS IAM user secret key

---

### 5.3. Infrastructure Teardown

**Workflows**: `eks-destroy-aws-infra.yaml` and `eks-destroy-hosted-zone.yaml`
**Trigger**: Manual (`workflow_dispatch`)
**Purpose**: Clean removal of all infrastructure in reverse dependency order

#### Workflow 1: eks-destroy-aws-infra.yaml

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

#### Workflow 2: eks-destroy-hosted-zone.yaml

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

## 6. Terraform Testing

### 6.1. Running Tests

**Test Runner**: `infra-eks/run-tests.sh`

```bash
cd infra-eks/
chmod +x run-tests.sh
./run-tests.sh
```

**What It Does**:
- Runs all `.tftest.hcl` files in `tests/unit/` using `terraform test`
- Tests run in **plan mode** (no real AWS resources created)
- Uses mock AWS credentials
- Outputs test results to `test.log`

**CI/CD Integration**: Tests automatically run in the `test-eks-terraform-modules` job before any deployment.

---

### 6.2. Test Files Explained

All test files use Terraform's native testing framework (introduced in Terraform 1.6+). Tests use mock AWS credentials and validate module configuration without creating real resources.

#### Available Test Files

1. **ecr.tftest.hcl** - Tests ECR repository configuration, lifecycle policies, and image scanning
2. **ssl.tftest.hcl** - Tests ACM certificate configuration, DNS validation, and SANs
3. **hosted_zone.tftest.hcl** - Tests Route 53 Hosted Zone configuration
4. **eks_cluster.tftest.hcl** - Tests EKS cluster configuration, IAM roles, and OIDC provider
5. **eks_node_group.tftest.hcl** - Tests node group configuration, Auto Scaling, and IAM roles
6. **aws_lb_controller.tftest.hcl** - Tests Load Balancer Controller Helm deployment and IRSA
7. **k8s_app.tftest.hcl** - Tests Kubernetes Deployment, Service, Ingress, and HPA configuration

**Test Coverage**: The tests validate module inputs, outputs, resource configuration, IAM policies, and environment-specific behavior.

---

## 7. Project Structure

```
infra-eks/
├── deployment/                 # Root modules (environment-specific)
│   ├── backend/                # S3 state bucket
│   ├── ecr/                    # ECR repository
│   ├── hosted_zone/            # Route 53 Hosted Zone
│   ├── ssl/                    # ACM certificate
│   ├── app/                    # Application infrastructure (EKS-specific)
│   │   ├── vpc/                # VPC and networking (with EKS tags)
│   │   ├── eks_cluster/        # EKS cluster (control plane)
│   │   ├── eks_node_group/     # Worker nodes with Auto Scaling
│   │   ├── aws_lb_controller/  # AWS Load Balancer Controller (Helm)
│   │   ├── k8s_app/            # Kubernetes Deployment/Service/Ingress/HPA
│   │   └── routing/            # Route 53 A records
│   ├── common.tfvars           # Shared configuration
│   ├── domain.tfvars           # Domain-specific configuration
│   ├── backend.tfvars          # Backend configuration
│   └── backend-config.hcl      # Backend initialization config
│
├── modules/                    # Child modules (reusable)
│   ├── aws_lb_controller/      # AWS Load Balancer Controller module
│   ├── ecr/                    # ECR module
│   ├── eks_cluster/            # EKS cluster module
│   ├── eks_node_group/         # EKS node group module
│   ├── hosted_zone/            # Route 53 Hosted Zone module
│   ├── k8s_app/     # Kubernetes application module
│   ├── routing/                # Route 53 routing module
│   └── ssl/                    # ACM certificate module
│
├── k8s-manifests/              # Optional: Raw Kubernetes manifests (for reference)
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── hpa.yaml
│
├── tests/                      # Terraform tests
│   ├── unit/                   # Unit tests for modules
│   │   ├── aws_lb_controller.tftest.hcl
│   │   ├── ecr.tftest.hcl
│   │   ├── eks_cluster.tftest.hcl
│   │   ├── eks_node_group.tftest.hcl
│   │   ├── hosted_zone.tftest.hcl
│   │   ├── k8s_app.tftest.hcl
│   │   └── ssl.tftest.hcl
│   └── versions.tf             # Provider versions for tests
│
├── docs/                       # Additional documentation
│   ├── GETTING-STARTED.md
│   ├── QUICKSTART.md
│   ├── ECS-vs-EKS-COMPARISON.md
│   └── ...
│
├── scripts/                    # Utility scripts
│   └── generate-manifests.sh
│
├── run-tests.sh                # Test runner script
├── test-runner.tf              # Test configuration
└── test.log                    # Test output log
```

---

**For questions or issues, please refer to the [root README](../README.md) or open an issue in the GitHub repository.**
