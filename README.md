# High-Availability App with AWS & Terraform

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-623CE4?logo=terraform&logoColor=white)](https://terraform.io)
[![AWS](https://img.shields.io/badge/AWS-ECS%20%7C%20EKS-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com)
[![NestJS](https://img.shields.io/badge/NestJS-10+-E0234E?logo=nestjs&logoColor=white)](https://nestjs.com)
[![TypeScript](https://img.shields.io/badge/TypeScript-5+-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![Docker](https://img.shields.io/badge/Docker-20+-2496ED?logo=docker&logoColor=white)](https://www.docker.com)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://github.com/pre-commit/pre-commit)

A hands-on learning project demonstrating production-ready, highly-available AWS infrastructure deployment using Terraform. This repository implements the same containerized NestJS application using **two different orchestration approaches**: AWS ECS (simpler, AWS-native) and AWS EKS (Kubernetes-based, cloud-agnostic).

## Table of Contents

1. [Motivation & Learning Goals](#motivation--learning-goals)
2. [What You'll Learn](#what-youll-learn)
3. [Application Overview](#application-overview)
4. [Infrastructure Approaches](#infrastructure-approaches)
   - [ECS Approach (Simpler)](#ecs-approach-simpler)
   - [EKS Approach (Kubernetes)](#eks-approach-kubernetes)
   - [EKS vs ECS](#eks-vs-ecs)
5. [Choose Your Path](#choose-your-path)
6. [Developer Setup: Pre-commit Hooks](#developer-setup-pre-commit-hooks)
7. [Quick Start](#quick-start)
8. [Project Structure](#project-structure)
9. [Known Limitations](#known-limitations)
10. [Contributing](#contributing)
11. [License](#license)
12. [Questions or Issues?](#questions-or-issues)

---

## Motivation & Learning Goals

This project was built as a **practical, hands-on learning experience** to master Infrastructure as Code (IaC) and cloud-native deployment patterns. The primary goals are:

- **Master Terraform**: Learn to define, version, and manage cloud infrastructure as code
- **Understand AWS Services**: Gain practical experience with VPC, ECS, EKS, ALB, Route53, ACM, ECR, and IAM
- **Compare Orchestration Approaches**: Understand the trade-offs between AWS ECS and Kubernetes (EKS)
- **Build Reusable Modules**: Create production-ready Terraform modules that follow best practices
- **Implement High Availability**: Design fault-tolerant architecture across multiple availability zones
- **Automate with CI/CD**: Use GitHub Actions for consistent, repeatable infrastructure deployment

This repository demonstrates complete, working implementations of both approaches, allowing you to learn by example and experimentation.

---

## What You'll Learn

By working through this project, you'll gain practical experience with:

**Core Infrastructure Concepts:**
- Resources deployed across multiple availability zones (AZ)
- Multi-AZ VPC architecture with public/private subnets
   - Containers run in private subnets with NAT Gateway
- Container orchestration with ECS and Kubernetes
- Load balancing
- HTTPS with SSL/TLS - Automatic certificate validation via ACM
- DNS management and domain routing
- Least-privilege network access control via security groups
- Service-to-service authorization without credentials with IAM role-based access control
- Auto-scaling for both compute and containers

**Terraform Best Practices:**
- Module architecture (root modules vs child modules)
- Remote state management with S3
- Environment-specific configuration (dev vs prod)
- Terraform automated testing for all modules
- Auto-generated documentation with terraform-docs
- Staged deployment with dependencies

**AWS Services Deep Dive:**
- ECS: Clusters, Services, Tasks, Capacity Providers
- EKS: Control plane, Node groups, AWS Load Balancer Controller
- Kubernetes resources via Terraform provider
- ECR with lifecycle policies
- Application Load Balancer with target groups
- Route53 and ACM certificate validation

**DevOps Practices:**
- GitHub Actions workflows for infrastructure automation (deployment and teardown)
- Pre-commit hooks for code quality, security, and formatting enforcement
- AWS ECR-based Docker container registry with automated lifecycle management
- Dependency-aware staged deployment order
- Infrastructure testing and validation before deployment

**Cost Optimization Techniques:**
- Environment-specific resource sizing
- Single NAT Gateway option for dev environments
- Spot instances for non-production EKS workloads
- ECR lifecycle policies to perform image cleanup and minimize storage costs

---

## Application Overview

The deployed application is a minimal **NestJS API** serving two endpoints:

| Endpoint | Description |
|----------|-------------|
| `GET /` | Returns "Hello World!" |
| `GET /health` | Returns `true`, logs unique instance ID for diagnostics, used by health checks |

The application runs in Docker containers on port **3000**, using `pnpm` as the package manager. A unique instance ID is generated on startup to demonstrate load balancing across multiple containers.

**Docker Image**: Built from `Dockerfile` using Node.js Alpine, tagged with `${environment}-${git-sha}` format, and stored in AWS ECR with automated lifecycle management.

---

## Infrastructure Approaches

This repository provides **two complete, independent implementations** of the same application using different container orchestration strategies.

### ECS Approach (Simpler)

**Location**: [`infra-ecs/`](infra-ecs/)

AWS Elastic Container Service (ECS) provides a simpler, AWS-native container orchestration platform with managed EC2 instances.

**Key Characteristics:**
- ✅ **Lower complexity** - Fewer concepts to learn
- ✅ **AWS-native** - Deep integration with AWS services
- ✅ **Lower cost** - No control plane charges
- ✅ **Faster deployment** - Simpler architecture, quicker to provision
- ⚠️ **AWS-specific** - Not portable to other clouds

**Architecture Highlights:**
- ECS Cluster with Auto Scaling Group (EC2-based)
- Capacity Provider for automatic scaling
- Task placement strategies (binpack for dev, spread for prod)
- Direct ALB creation via Terraform

**Best For:**
- Learning AWS container services
- Production workloads staying on AWS
- Cost-sensitive projects
- Teams without Kubernetes expertise

📖 **[Full ECS Documentation →](infra-ecs/README.md)**

---

### EKS Approach (Kubernetes)

**Location**: [`infra-eks/`](infra-eks/)

AWS Elastic Kubernetes Service (EKS) provides a managed Kubernetes control plane with full Kubernetes API compatibility.

**Key Characteristics:**
- ✅ **Cloud-agnostic** - Portable across cloud providers
- ✅ **Industry standard** - Kubernetes skills are transferable
- ✅ **Rich ecosystem** - Access to Kubernetes tooling and operators
- ✅ **Advanced features** - StatefulSets, DaemonSets, CRDs, operators
- ⚠️ **Higher complexity** - Steeper learning curve
- ⚠️ **Higher cost** - Control plane has some associated costs

**Architecture Highlights:**
- Managed EKS control plane across multiple AZs
- Managed node groups with Auto Scaling
- AWS Load Balancer Controller (Helm chart with IRSA)
- Kubernetes resources managed via Terraform provider
- Horizontal Pod Autoscaler (HPA) for application scaling

**Best For:**
- Learning Kubernetes on AWS
- Multi-cloud or hybrid deployments
- Teams with Kubernetes expertise
- Complex microservices architectures (3+ services)
- Organizations avoiding vendor lock-in

📖 **[Full EKS Documentation →](infra-eks/README.md)**

---

### EKS vs ECS

#### Key Differences

#### 1. Container Orchestration

**ECS:**
- AWS-proprietary container orchestration
- Task definitions define containers
- ECS service manages desired count
- Tightly integrated with AWS services

**EKS:**
- Standard Kubernetes (K8s) orchestration
- Deployments + Pods define containers
- ReplicaSets manage desired count
- Portable across clouds (AWS, GCP, Azure, on-prem)

#### 2. Networking

**ECS:**
- ECS tasks use ENIs (awsvpc mode)
- ALB target groups register tasks directly
- Security groups on tasks

**EKS:**
- Pods use AWS VPC CNI for IP addresses
- ALB Ingress Controller creates target groups
- Security groups on nodes + network policies

#### 3. Scaling

**ECS:**
- ECS Capacity Provider scales EC2 instances
- ECS Service Auto Scaling scales tasks
- Target tracking based on CPU/memory

**EKS:**
- Cluster Autoscaler scales nodes
- Horizontal Pod Autoscaler (HPA) scales pods
- Metrics Server provides resource metrics

#### 4. Service Discovery

**ECS:**
- AWS Cloud Map for service discovery
- ALB for external load balancing
- ECS service connects to target groups

**EKS:**
- Kubernetes DNS (CoreDNS) for service discovery
- AWS Load Balancer Controller for external LB
- Ingress resources create ALBs automatically

#### 5. IAM Permissions

**ECS:**
- Task Role: IAM role for application
- Execution Role: IAM role for ECS agent
- Directly attached to task definition

**EKS:**
- ServiceAccount: Kubernetes identity for pods
- IRSA (IAM Roles for Service Accounts): Maps K8s SA to IAM role
- Annotated on ServiceAccount

#### ECS → EKS Component Mapping

| ECS Component | EKS Equivalent | Description |
|---------------|----------------|-------------|
| **ECS Cluster** | **EKS Cluster** | Control plane for container orchestration |
| **ECS EC2 Launch Template + ASG** | **EKS Node Group** | Managed EC2 instances running Kubernetes |
| **ECS Task Definition** | **Kubernetes Deployment** | Application container specifications |
| **ECS Service** | **Kubernetes Service + Ingress** | Load balancing and service discovery |
| **ALB Target Group** | **AWS Load Balancer Controller** | Ingress controller managing ALB |
| **ECS Task Role** | **Kubernetes ServiceAccount + IRSA** | Pod-level IAM permissions |

#### Summary Comparison

| Aspect | ECS (infra-ecs/) | EKS (infra-eks/) |
|--------|------------------|------------------|
| **Orchestration** | AWS ECS (proprietary) | Kubernetes (open-source) |
| **Control Plane** | Free, managed by AWS ECS | Not free, managed by AWS EKS |
| **Total Monthly Cost** | Cheap (`x`) | Expensive (`2x`) |
| **Learning Curve** | Easier | Steeper |
| **Complexity** | Lower | Higher |
| **Portability** | AWS-only | Multi-cloud |
| **Ecosystem** | AWS services | Kubernetes ecosystem |
| **Load Balancing** | ALB managed by Terraform | ALB managed by Ingress Controller |
| **Scaling** | ECS Service auto-scaling + Capacity Provider | Horizontal Pod Autoscaler (HPA) + Cluster Autoscaler |
| **Workload Definition** | Task Definition + Service | Deployment + Service + Ingress |
| **Networking** | awsvpc mode with ENI per task | Kubernetes CNI (AWS VPC CNI) |
| **Use Case** | AWS-committed workloads | Kubernetes-native or multi-cloud |

**Can I run both simultaneously?** Yes! The implementations use separate Terraform state files (`deployment/` vs `deployment/app/`) and independent resources, allowing side-by-side deployment for comparison.

---

## Choose Your Path

Ready to get started? Choose the path that matches your goal:

### Path 1: I Want to Deploy the ECS-Based Solution

**Best for**: Quickly getting a production-ready AWS infrastructure running with minimal Kubernetes complexity.

**Steps**:
1. **Review Prerequisites**: Check [ECS Prerequisites](infra-ecs/README.md#21-prerequisites)
2. **Configure Your Settings**: Follow [Required Configuration Changes](infra-ecs/README.md#22-required-configuration-changes)
3. **Deploy Using CI/CD**: Use [GitHub Actions Workflows](infra-ecs/README.md#5-cicd-workflows) for automated deployment
4. **Verify Deployment**: Access your application at `https://yourdomain.com`

**Estimated Time**: 30-45 minutes

---

### Path 2: I Want to Deploy the EKS-Based Solution

**Best for**: Learning Kubernetes on AWS or preparing for multi-cloud/portable deployments.

**Steps**:
1. **Review Prerequisites**: Check [EKS Prerequisites](infra-eks/README.md#21-prerequisites)
2. **Configure Your Settings**: Follow [Required Configuration Changes](infra-eks/README.md#22-required-configuration-changes)
3. **Deploy Using CI/CD**: Use [GitHub Actions Workflows](infra-eks/README.md#5-cicd-workflows) for automated deployment
4. **Verify Deployment**: Configure kubectl and access your application at `https://yourdomain.com`

**Estimated Time**: 45-60 minutes

---

### Path 3: I Want to Understand the ECS-Based Solution

**Best for**: Learning AWS-native container orchestration without Kubernetes complexity.

**Learning Journey**:
1. **Start with Overview**: Read [ECS High-Level Overview](infra-ecs/README.md#1-high-level-overview)
2. **Module Architecture**: Understand [Root vs Child Modules](infra-ecs/README.md#31-module-architecture-root-modules-vs-child-modules)
3. **Deep Dive into Components**:
   - [VPC & Networking](infra-ecs/README.md#311-shared-resources-vpc-ecr-ssl-hosted-zone)
   - [ECS Cluster](infra-ecs/README.md#312-ecs-cluster)
   - [Application Load Balancer](infra-ecs/README.md#313-application-load-balancer-alb)
   - [ECS Service](infra-ecs/README.md#314-ecs-service)
   - [IAM Roles](infra-ecs/README.md#315-iam-roles-and-permissions)
   - [Security Groups](infra-ecs/README.md#316-security-groups)
4. **Environment Configuration**: Study [dev vs prod Differences](infra-ecs/README.md#4-environment-configuration-differences)
5. **Explore Testing**: Review [Terraform Testing](infra-ecs/README.md#6-terraform-testing)

**Key Concepts**: ECS Task Definitions, Capacity Providers, awsvpc networking, task placement strategies

---

### Path 4: I Want to Understand the EKS-Based Solution

**Best for**: Learning Kubernetes on AWS and cloud-agnostic container orchestration.

**Learning Journey**:
1. **Start with Overview**: Read [EKS High-Level Overview](infra-eks/README.md#1-high-level-overview)
2. **Module Architecture**: Understand [Root vs Child Modules](infra-eks/README.md#31-module-architecture-root-modules-vs-child-modules)
3. **Deep Dive into Components**:
   - [VPC & Networking](infra-eks/README.md#311-shared-resources-vpc-ecr-ssl-hosted-zone)
   - [EKS Cluster](infra-eks/README.md#312-eks-cluster)
   - [EKS Node Group](infra-eks/README.md#313-eks-node-group)
   - [AWS Load Balancer Controller](infra-eks/README.md#314-aws-load-balancer-controller)
   - [Kubernetes Application](infra-eks/README.md#315-kubernetes-application-k8s_app)
   - [IAM Roles (IRSA)](infra-eks/README.md#316-iam-roles-and-permissions)
4. **Environment Configuration**: Study [dev vs prod Differences](infra-eks/README.md#4-environment-configuration-differences)
5. **Explore Testing**: Review [Terraform Testing](infra-eks/README.md#6-terraform-testing)
6. **Compare Approaches**: Read [EKS vs ECS Comparison](infra-eks/docs/ECS-vs-EKS-COMPARISON.md)

**Key Concepts**: Kubernetes Deployments, HPA, IRSA, AWS Load Balancer Controller, Managed Node Groups

---

## Developer Setup: Pre-commit Hooks

This project uses pre-commit hooks to enforce code quality, security, and formatting standards before commits. The hooks automatically format Terraform files, validate syntax, check for security issues, and prevent secret commits.

### Prerequisites

- Python 3.7+ (for pre-commit framework)
- Terraform 1.0+
- Homebrew (macOS/Linux)

### Installation

```bash
# 1. Install pre-commit
brew install pre-commit

# 2. Install TFLint
brew install tflint
tflint --init  # Install TFLint AWS plugin

# 3. Install tfsec (security scanner)
brew install tfsec

# 4. Install detect-secrets
brew install detect-secrets

# 5. Install terraform-docs
brew install terraform-docs

# 6. Install the pre-commit hooks
pre-commit install

# 7. (Optional) Test hooks against all files
pre-commit run --all-files
```

### Usage

Once installed, hooks run automatically on `git commit`:

**If hooks fail due to formatting:**
```bash
# Files are auto-formatted but not staged
# Review changes, then:
git add .
git commit -m "Your message"
```

**Recommended workflow** (avoid commit rejection):
```bash
# 1. Format before staging
terraform fmt -recursive infra-ecs/
terraform fmt -recursive infra-eks/

# 2. Stage and commit (hooks pass on first attempt)
git add .
git commit -m "Your message"
```

**To skip hooks** (⚠️ not recommended):
```bash
git commit --no-verify
```

**Available hooks:**
- `terraform_fmt` - Format Terraform files
- `terraform_validate` - Validate Terraform syntax
- `terraform_tflint` - Lint Terraform code
- `terraform_trivy` - Security vulnerability scanning
- `terraform_docs` - Generate module documentation
- `detect-secrets` - Prevent commits including secrets
- `terraform_test` - Run Terraform tests

---

## Quick Start

### Prerequisites

- AWS Account with appropriate IAM permissions
- **Domain name** (required for SSL certificates)
- Terraform 1.0+ installed
- AWS CLI configured (`aws configure`)
- kubectl (for EKS only)
- Helm (for EKS only)

### Choose Your Approach

#### Option 1: ECS (Simpler) - 30 Minutes

```bash
cd infra-ecs/

# 1. Configure your settings
cd deployment/
# See infra-ecs/README.md for detailed steps

# 2. Deploy ECS infrastructure by committing changes
# See infra-ecs/README.md for detailed steps

# 3. Access your application
# https://yourdomain.com
```

📖 **[Detailed ECS Quick Start →](infra-ecs/README.md#2-prerequisites-and-first-time-setup)**

#### Option 2: EKS (Kubernetes) - 45 Minutes

```bash
cd infra-eks/

# 1. Configure your settings
cd deployment/
# See infra-eks/README.md for detailed steps

# 2. Deploy EKS infrastructure by committing changes
# See infra-eks/README.md for detailed steps

# 3. Access your application
# https://yourdomain.com
```

📖 **[Detailed EKS Quick Start →](infra-eks/README.md#2-prerequisites-and-first-time-setup)**

### Using GitHub Actions (CI/CD)

Both implementations include complete GitHub Actions workflows:

1. Configure AWS credentials as GitHub secrets
2. Update configuration files with your values
3. Copy and paste either ECS or EKS workflow files into your `.github/workflows/` directory
4. Trigger workflows via GitHub UI or `git push`

📖 **ECS Workflows**: [infra-ecs/README.md - Section 5](infra-ecs/README.md#5-cicd-workflows) <br>
📖 **EKS Workflows**: [infra-eks/README.md - Section 5](infra-eks/README.md#5-cicd-workflows)

---

## Project Structure

```
.
├── infra-ecs/                 # ECS implementation (simpler, AWS-native)
│   ├── deployment/            # Root modules (orchestration)
│   │   ├── backend/           # S3 state bucket
│   │   ├── hosted_zone/       # Route53 DNS
│   │   ├── ssl/               # ACM certificate
│   │   ├── ecr/               # Container registry
│   │   └── app/               # ECS-specific infrastructure
│   │       ├── vpc/           # Network
│   │       ├── ecs_cluster/   # ECS cluster + ASG
│   │       ├── alb/           # Load balancer
│   │       ├── ecs_service/   # Container service
│   │       └── routing/       # DNS records
│   ├── modules/               # Child modules (reusable)
│   ├── tests/                 # Terraform tests
│   ├── docs/                  # Additional documentation
│   └── README.md              # Complete ECS documentation
│
├── infra-eks/                 # EKS implementation (Kubernetes-based)
│   ├── deployment/            # Root modules (orchestration)
│   │   ├── backend/           # S3 state bucket
│   │   ├── hosted_zone/       # Route53 DNS
│   │   ├── ssl/               # ACM certificate
│   │   ├── ecr/               # Container registry
│   │   └── app/               # EKS-specific infrastructure
│   │       ├── vpc/           # Network (with EKS tags)
│   │       ├── eks_cluster/   # EKS control plane
│   │       ├── eks_node_group/# Worker nodes
│   │       ├── aws_lb_controller/  # Ingress controller
│   │       ├── k8s_app/       # Kubernetes resources
│   │       └── routing/       # DNS records
│   ├── modules/               # Child modules (reusable)
│   ├── tests/                 # Terraform tests
│   ├── docs/                  # Additional documentation
│   └── README.md              # Complete EKS documentation
│
├── .github/workflows/         # GitHub Actions CI/CD
│   ├── ecs/                   # ECS workflows
│   └── eks/                   # EKS workflows
│
├── src/                       # NestJS application
├── Dockerfile                 # Container image definition
├── .pre-commit-config.yaml    # Pre-commit hooks config
└── README.md                  # This file
```

---

## Known Limitations

### Terraform State Locking

This project does **not** implement DynamoDB state locking for Terraform remote state.

**What this means:**
- **Single developer**: Safe to use as-is
- **Team collaboration**: Risk of state corruption from concurrent operations
- **Production teams**: Should implement state locking

**Why it matters:**
- Concurrent `terraform apply` operations can corrupt the state file
- Multiple developers/pipelines can create race conditions
- Changes may be overwritten or lost

**To enable state locking:**
1. Create a DynamoDB table with `LockID` as the primary key (hash key)
2. Uncomment the `dynamodb_table` parameter in all `backend.tf` files
3. Update with your DynamoDB table name
4. Ensure team members have DynamoDB permissions

**Current state**: All `backend.tf` files have `dynamodb_table` commented out for simplicity in learning environments.

**Recommendation**:
- **Learning/Solo**: Can safely omit for reduced complexity
- **Production/Team**: Always enable state locking

### Additional Known Issues

For a complete list of known issues, limitations, and planned improvements, please refer to the [Issues](../../issues) section of this GitHub repository. This includes:

- Bug reports and fixes
- Feature requests and enhancements
- Documentation improvements
- Infrastructure optimization opportunities

If you encounter any issues not listed there, please [open a new issue](../../issues/new) with detailed information about the problem.

---

## Contributing

This is a learning project, but contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Ensure all pre-commit hooks pass
4. Submit a pull request with a clear description

---

## License

This project is open source and available under the [MIT License](LICENSE).

---

## Questions or Issues?

- **ECS-specific questions**: See [`infra-ecs/README.md`](infra-ecs/README.md)
- **EKS-specific questions**: See [`infra-eks/README.md`](infra-eks/README.md)
- **General issues**: Open an issue on GitHub

---

**Happy Learning! 🚀**
