# EKS Infrastructure Documentation

This directory contains the complete Terraform infrastructure for deploying a high-availability NestJS application using AWS Elastic Kubernetes Service (EKS). The implementation follows Infrastructure as Code (IaC) principles with modular, reusable components and leverages Kubernetes for container orchestration.

## Documentation Index

| Document | Description |
|----------|-------------|
| **[Prerequisites and Setup](docs/PREREQUISITES_AND_SETUP.md)** | Complete guide for first-time configuration, AWS credentials setup, kubectl/helm installation, and domain configuration |
| **[AWS Resources Deep Dive](docs/AWS_RESOURCES_DEEP_DIVE.md)** | In-depth technical documentation of all AWS resources, module architecture, IAM policies, and security groups (consolidated) |
| **[CI/CD Workflows](docs/CICD_WORKFLOWS.md)** | GitHub Actions workflows for automated deployment and teardown |
| **[Terraform Testing](docs/TERRAFORM_TESTING.md)** | Testing framework, troubleshooting guide (including Kubernetes provider issues), and detailed test suite documentation |
| **[Kubernetes Basics](docs/KUBERNETES_BASICS.md)** | Introduction to Kubernetes concepts, AWS EKS specifics, and learning resources |

---

## Before You Begin

**Required Setup:** Before deploying this infrastructure, you must configure several variables and files with your own values. See the **[Prerequisites and Setup Guide](docs/PREREQUISITES_AND_SETUP.md)** for:
- AWS account and domain requirements
- S3 backend configuration
- Project name and environment setup
- kubectl and Helm installation
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

The EKS infrastructure implements a production-ready, highly available Kubernetes platform on AWS. The architecture leverages managed Kubernetes services (EKS), AWS Load Balancer Controller for native ALB integration, and Horizontal Pod Autoscaling for dynamic workload management.

### 1.1. Key Components and Their Relationships

```
Internet
    ↓
[Route 53] → Points to ALB DNS (created by Ingress)
    ↓
[Application Load Balancer (ALB)] ← Created by AWS Load Balancer Controller
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

### 1.2. Traffic Flow

1. **Inbound Traffic**: User requests hit Route 53 → ALB (validates SSL certificate) → Kubernetes Ingress → Kubernetes Service → Pods on worker nodes
2. **Outbound Traffic**: Pods → NAT Gateway (in public subnets) → Internet Gateway → Internet

### 1.3. Core Design Principles

- **High Availability**: Multi-AZ deployment for both control plane and worker nodes
- **Security**: Private subnets for compute, security groups with least-privilege access, IAM roles for service accounts (IRSA)
- **Scalability**: Cluster Autoscaler for worker nodes, Horizontal Pod Autoscaler (HPA) for pods
- **Kubernetes-Native**: Ingress resources for ALB management, native Kubernetes service discovery and load balancing
- **Modularity**: Reusable Terraform modules following Single Responsibility Principle
- **Environment Flexibility**: Configuration-driven differences between dev and prod environments

### 1.4. High-Level Architecture

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

---

## 2. Key Components

| AWS/Kubernetes Component | Role in the Architecture |
| :--- | :--- |
| **Route 53 & ACM** | The Route 53 Hosted Zone manages DNS records. AWS Certificate Manager (ACM) provides and validates the SSL certificate, which is attached to the ALB (created by Ingress) for secure HTTPS communication. |
| **Application Load Balancer (ALB)** | Dynamically created by AWS Load Balancer Controller when Kubernetes Ingress resources are deployed. Distributes incoming traffic, listens on Port 443 (HTTPS), and redirects Port 80 (HTTP) to HTTPS. Routes traffic directly to pod IPs when using `target-type: ip`. |
| **Kubernetes Ingress** | Defines HTTP/HTTPS routing rules from outside the cluster to Services. When an Ingress is created, the AWS Load Balancer Controller automatically provisions an ALB with the specified configuration (SSL certificate, listeners, routing rules). |
| **Kubernetes Service** | Provides a stable internal endpoint (ClusterIP) for a set of pods. Acts as an internal load balancer within the cluster, distributing traffic across healthy pods based on their readiness probe status. |
| **Kubernetes Pod** | The smallest deployable unit containing one or more containers. Pods are scheduled on worker nodes and receive VPC IP addresses via AWS VPC CNI plugin, enabling direct communication with ALB and other AWS services. |
| **Kubernetes Deployment** | Manages the desired state of pod replicas, handles rolling updates, rollbacks, and ensures the specified number of pods are always running. Works with HPA for automatic scaling. |
| **Horizontal Pod Autoscaler (HPA)** | Automatically scales the number of pod replicas based on CPU/memory utilization or custom metrics. Queries metrics from Kubernetes Metrics Server and adjusts Deployment replica count. |
| **EKS Cluster (Control Plane)** | AWS-managed Kubernetes control plane running across multiple AZs. Includes the API server, etcd, scheduler, and controller manager. Provides the Kubernetes API endpoint that kubectl and other tools communicate with. |
| **EKS Node Group** | Manages EC2 worker nodes that run Kubernetes pods. Uses Auto Scaling Groups for dynamic scaling based on pod resource requests. Nodes are deployed in private subnets with security groups controlling access. |
| **AWS Load Balancer Controller** | Kubernetes controller (deployed via Helm) that watches for Ingress/Service resources and automatically creates/manages ALBs, target groups, and listeners in AWS. Uses IAM Roles for Service Accounts (IRSA) for AWS API access. |
| **Virtual Private Cloud (VPC)** | Provides isolated network infrastructure with EKS-specific subnet tags. Public subnets host ALBs and NAT Gateways. Private subnets host worker nodes. Tags like `kubernetes.io/role/elb` enable automatic subnet discovery by the Load Balancer Controller. |
| **Elastic Container Registry (ECR)** | A private Docker registry storing application container images with lifecycle policies for automated cleanup. Images are pulled by worker nodes during pod deployment. |

**For detailed technical documentation** on module architecture, IAM policies (consolidated section with all 3 roles), security groups, and resource configurations, see **[AWS Resources Deep Dive](docs/AWS_RESOURCES_DEEP_DIVE.md)**.

**For Kubernetes fundamentals** and AWS EKS-specific concepts, see **[Kubernetes Basics](docs/KUBERNETES_BASICS.md)**.

---

## 3. Environment Configuration Differences

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

## 4. CI/CD Workflows

All infrastructure deployment and teardown is managed through **GitHub Actions workflows** located in `.github/workflows/eks/`. These workflows automate Terraform operations in a dependency-aware order.

### Quick Overview

**Deployment Stages:**
1. **Initial Setup** (Manual) - Deploy S3 state bucket and Route53 hosted zone
2. **Full Deployment** (On push to main) - Complete infrastructure from ECR to running Kubernetes application (11 steps)
3. **Teardown** (Manual) - Clean removal in reverse dependency order

### Workflow Files

- `eks-deploy-hosted-zone.yaml` - One-time setup of foundational infrastructure
- `eks-deploy-aws-infra.yaml` - Full deployment pipeline (ECR → SSL → Docker image → VPC → EKS Cluster → Node Group → AWS LB Controller → K8s App → Routing)
- `eks-destroy-aws-infra.yaml` - Application infrastructure teardown (includes cleanup of orphaned ALBs/SGs)
- `eks-destroy-hosted-zone.yaml` - DNS and state storage cleanup

### Required GitHub Secrets

- `AWS_ACCESS_KEY_ID` - AWS IAM user access key
- `AWS_SECRET_ACCESS_KEY` - AWS IAM user secret key

### Key EKS-Specific Steps

- **kubectl Configuration**: Workflows configure kubectl access to EKS cluster using AWS CLI
- **Helm Installation**: AWS Load Balancer Controller is installed via Terraform Helm provider
- **Ingress Wait Time**: Deployment waits 5-10 minutes for ALB provisioning after Ingress creation
- **Manual Ingress Deletion**: During teardown, Ingress resources are manually deleted to ensure proper ALB cleanup

**For detailed workflow documentation**, job sequences, manual steps, and troubleshooting, see **[CI/CD Workflows](docs/CICD_WORKFLOWS.md)**.

---

## 5. Terraform Testing

### Running Tests Locally

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

### Test Coverage

The test suite validates 7 core modules:
- **ecr.tftest.hcl** - Repository configuration, lifecycle policies, image scanning
- **ssl.tftest.hcl** - Certificate configuration, DNS validation, SANs
- **hosted_zone.tftest.hcl** - Route 53 zone configuration, force_destroy settings
- **eks_cluster.tftest.hcl** - Cluster, IAM roles, security groups, logging
- **eks_node_group.tftest.hcl** - Node group, scaling, capacity types, launch template
- **aws_lb_controller.tftest.hcl** - OIDC provider, IAM configuration, Helm deployment
- **k8s_app.tftest.hcl** - Deployment, Service, HPA, Ingress, security context

### EKS-Specific Testing Considerations

- **Mock AWS Credentials**: Required for provider initialization even in plan mode
- **Kubernetes Provider**: Tests use mock configuration - unset `KUBECONFIG` to avoid interference
- **No Cluster Required**: All tests run in plan mode without actual cluster connectivity

### CI/CD Integration

Tests automatically run in the `test-eks-terraform-modules` job before any deployment to validate all modules.

**For detailed test suite documentation**, troubleshooting guide (including Kubernetes provider issues), and comprehensive test explanations, see **[Terraform Testing](docs/TERRAFORM_TESTING.md)**.

---

## 6. Project Structure

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
│   ├── k8s_app/                # Kubernetes application module
│   ├── routing/                # Route 53 routing module
│   └── ssl/                    # ACM certificate module
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
├── docs/                       # Documentation
├── run-tests.sh                # Test runner script
├── test-runner.tf              # Test configuration
└── test.log                    # Test output log
```

---

**For questions or issues, please refer to the [root README](../README.md) or open an issue in the GitHub repository.**
