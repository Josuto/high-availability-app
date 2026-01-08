# AWS Resources Deep Dive

This document provides comprehensive documentation of all AWS resources, Terraform modules, and infrastructure components used in the ECS-based deployment.

## Table of Contents

1. [Module Architecture: Root Modules vs Child Modules](#1-module-architecture-root-modules-vs-child-modules)
2. [Foundational Infrastructure (Approach-Agnostic)](#2-foundational-infrastructure-approach-agnostic)
   - [2.1. Elastic Container Registry (ECR)](#21-elastic-container-registry-ecr)
   - [2.2. SSL Certificate (ACM)](#22-ssl-certificate-acm)
   - [2.3. Route 53 Hosted Zone](#23-route-53-hosted-zone)
3. [Application Deployment Infrastructure (ECS-Specific)](#3-application-deployment-infrastructure-ecs-specific)
   - [3.1. Virtual Private Cloud (VPC)](#31-virtual-private-cloud-vpc)
   - [3.2. ECS Cluster](#32-ecs-cluster)
   - [3.3. Application Load Balancer (ALB)](#33-application-load-balancer-alb)
   - [3.4. ECS Service](#34-ecs-service)
   - [3.5. Routing](#35-routing)
   - [3.6. IAM Roles and Policies](#36-iam-roles-and-policies)
   - [3.7. Security Groups](#37-security-groups)

---

## 1. Module Architecture: Root Modules vs Child Modules

The infrastructure follows a strict separation between **Root Modules** (deployment stages) and **Child Modules** (reusable components), implementing the Single Responsibility Principle and maximizing reusability.

### Child Modules (`infra-ecs/modules/*`)

Child modules are **single-purpose, reusable infrastructure components** that define specific AWS resources:
- Examples: `ecr`, `alb`, `ecs_cluster`, `ecs_service`, `ssl`, `hosted_zone`, `routing`
- Accept inputs via variables (e.g., `var.vpc_id`, `var.project_name`)
- Return outputs (e.g., `alb_dns_name`, `ecs_cluster_arn`)
- **No knowledge** of other modules or deployment stages
- **No remote state references** - completely self-contained
- Designed for maximum portability and reusability across projects

### Root Modules (`infra-ecs/deployment/*`)

Root modules are **environment-specific orchestration layers** that:
- Stitch child modules together to create complete infrastructure stages
- Use `data "terraform_remote_state"` to read outputs from previous deployment stages
- Pass environment-specific configuration to child modules
- Examples: `deployment/app/vpc`, `deployment/app/ecs_cluster`, `deployment/app/alb`

### How They Work Together

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

## 2. Foundational Infrastructure (Approach-Agnostic)

These root modules represent **approach-agnostic infrastructure** - components that are shared between different container orchestration approaches (ECS and EKS implementations). They reside directly under `infra-ecs/deployment/` and provide foundational services required by any application deployment.

**Approach-Agnostic Modules:**
- **`backend/`**: S3 bucket for Terraform remote state storage
- **`hosted_zone/`**: Route53 hosted zone for DNS management (see [Section 2.3](#23-route-53-hosted-zone))
- **`ssl/`**: ACM SSL certificate for HTTPS (see [Section 2.2](#22-ssl-certificate-acm))
- **`ecr/`**: Docker container registry (see [Section 2.1](#21-elastic-container-registry-ecr))

**Key Characteristic:** These modules are not specific to ECS - the same modules are also used in the EKS implementation (`infra-eks/`), providing shared infrastructure across both approaches.

---

### 2.1. Elastic Container Registry (ECR)

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

### 2.2. SSL Certificate (ACM)

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

### 2.3. Route 53 Hosted Zone

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

**Note**: DNS records (A records) that point to the Application Load Balancer are created by the approach-specific routing module (see [Section 3.5](#35-routing)).

---

## 3. Application Deployment Infrastructure (ECS-Specific)

These root modules represent **ECS-specific application infrastructure** - components that are unique to the ECS cluster-based container orchestration approach. They reside under `infra-ecs/deployment/app/` and implement the compute, networking, and load balancing layers specific to running containers on ECS with EC2 instances.

**ECS-Specific Modules:**
- **`app/vpc/`**: Network infrastructure for ECS deployment (see [Section 3.1](#31-virtual-private-cloud-vpc))
- **`app/ecs_cluster/`**: ECS cluster with EC2 Auto Scaling Group (see [Section 3.2](#32-ecs-cluster))
- **`app/alb/`**: Application Load Balancer for traffic distribution (see [Section 3.3](#33-application-load-balancer-alb))
- **`app/ecs_service/`**: ECS service managing containerized tasks (see [Section 3.4](#34-ecs-service))
- **`app/routing/`**: Route 53 A records pointing to ALB (see [Section 3.5](#35-routing))

**Key Characteristic:** These modules implement ECS-specific concepts (clusters, services, tasks, capacity providers) and would be replaced by different modules in the EKS implementation (node groups, pods, deployments).

The following subsections provide detailed explanations of each infrastructure component, organized by category.

---

### 3.1. Virtual Private Cloud (VPC)

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

### 3.2. ECS Cluster

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

### 3.3. Application Load Balancer (ALB)

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

### 3.4. ECS Service

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

### 3.5. Routing

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

### 3.6. IAM Roles and Policies

The infrastructure uses two distinct IAM roles for different levels of authorization.

#### a) ECS EC2 Instance Role (`ecs_instance_role`)

**Assumed By**: EC2 container instances in the ECS cluster

**Purpose**: Grants EC2 instances permissions to interact with AWS services at the infrastructure level.

**1. Managed Policies Attached**:
- **AmazonEC2ContainerServiceforEC2Role** (`arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role`)
   - Enables EC2 instances to join/leave the cluster, poll for tasks, and manage container operations
   - Permissions: `ecs:RegisterContainerInstance`, `ecs:DeregisterContainerInstance`, `ecs:SubmitContainerStateChange`, `ecs:SubmitTaskStateChange`

- **AmazonSSMManagedInstanceCore** (`arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore`)
   - Enables AWS Session Manager (SSM) for secure shell access
   - Eliminates need for SSH keys and bastion hosts
   - Permissions: `ssm:UpdateInstanceInformation`, `ssmmessages:*`, `ec2messages:*`

**2. Custom Inline Policy** (`ecs_instance_policy`):
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
- **ECR Access**: Allows EC2 instances to authenticate with ECR and pull Docker images
- **CloudWatch Logs**: Enables operational logging from EC2 instance-level processes

**Module Location**: `infra-ecs/modules/ecs_cluster/iam.tf`

---

#### b) ECS Task Execution Role (`ecs_task_execution_role`)

**Assumed By**: ECS tasks (via the ECS agent)

**Purpose**: Grants the ECS service permissions to perform actions on behalf of your tasks.

**1. Managed Policy Attached**:
- **AmazonECSTaskExecutionRolePolicy** (`arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy`)
  - Allows ECS to pull container images from ECR
  - Allows ECS to write container application logs to CloudWatch
  - Permissions: `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:GetDownloadUrlForLayer`, `ecr:BatchGetImage`, `logs:CreateLogStream`, `logs:PutLogEvents`

**2. Custom Inline Policy** (`ecs_task_execution_policy`):
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

### 3.7. Security Groups

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

**Return to:** [Main README](../README.md) | [Prerequisites and Setup](PREREQUISITES_AND_SETUP.md) | [CI/CD Workflows](CICD_WORKFLOWS.md) | [Terraform Testing](TERRAFORM_TESTING.md)
