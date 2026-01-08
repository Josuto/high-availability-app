# AWS Resources Deep Dive

## Table of Contents

1. [Module Architecture: Root Modules vs Child Modules](#1-module-architecture-root-modules-vs-child-modules)
2. [Foundational Infrastructure (Approach-Agnostic)](#2-foundational-infrastructure-approach-agnostic)
   - [2.1. Elastic Container Registry (ECR)](#21-elastic-container-registry-ecr)
   - [2.2. SSL Certificate (ACM)](#22-ssl-certificate-acm)
   - [2.3. Route 53 Hosted Zone](#23-route-53-hosted-zone)
3. [Application Deployment Infrastructure (EKS-Specific)](#3-application-deployment-infrastructure-eks-specific)
   - [3.1. Virtual Private Cloud (VPC)](#31-virtual-private-cloud-vpc)
   - [3.2. EKS Cluster](#32-eks-cluster)
   - [3.3. EKS Node Group](#33-eks-node-group)
   - [3.4. AWS Load Balancer Controller](#34-aws-load-balancer-controller)
   - [3.5. Kubernetes Application Deployment](#35-kubernetes-application-deployment)
   - [3.6. Routing](#36-routing)
   - [3.7. IAM Roles and Policies](#37-iam-roles-and-policies)
   - [3.8. Security Groups](#38-security-groups)

---

## 1. Module Architecture: Root Modules vs Child Modules

The infrastructure follows a strict separation between **Root Modules** (deployment stages) and **Child Modules** (reusable components), implementing the Single Responsibility Principle and maximizing reusability.

### Child Modules (`infra-eks/modules/*`)

Child modules are **single-purpose, reusable infrastructure components** that define specific AWS resources:
- Examples: `ecr`, `eks_cluster`, `eks_node_group`, `aws_lb_controller`, `k8s_app`, `ssl`, `hosted_zone`, `routing`
- Accept inputs via variables (e.g., `var.vpc_id`, `var.project_name`)
- Return outputs (e.g., `cluster_id`, `cluster_oidc_issuer_url`)
- **No knowledge** of other modules or deployment stages
- **No remote state references** - completely self-contained
- Designed for maximum portability and reusability across projects

### Root Modules (`infra-eks/deployment/*`)

Root modules are **environment-specific orchestration layers** that:
- Stitch child modules together to create complete infrastructure stages
- Use `data "terraform_remote_state"` to read outputs from previous deployment stages
- Pass environment-specific configuration to child modules
- Examples: `deployment/app/vpc`, `deployment/app/eks_cluster`, `deployment/app/eks_node_group`

### How They Work Together

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

### Deployment Order and Dependencies

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

### Why This Architecture?

- **Reusability**: The `eks_cluster` child module can be used in any project that needs an EKS cluster, without copying VPC or node group code
- **Separation of Concerns**: Each child module has a single responsibility (e.g., EKS cluster module only manages the cluster control plane)
- **Staged Deployment**: Root modules enable deploying infrastructure in logical stages with clear dependencies
- **Environment Isolation**: Different environments (dev, prod) use the same child modules with different configuration values
- **State Isolation**: Each deployment stage has its own Terraform state file, reducing blast radius of changes

---

## 2. Foundational Infrastructure (Approach-Agnostic)

These root modules represent **approach-agnostic infrastructure** - components that are shared between different container orchestration approaches (ECS and EKS implementations). They reside directly under `infra-eks/deployment/` and provide foundational services required by any application deployment.

**Approach-Agnostic Modules:**
- **`backend/`**: S3 bucket for Terraform remote state storage
- **`ecr/`**: Docker container registry (see [Section 2.1](#21-elastic-container-registry-ecr))
- **`ssl/`**: ACM SSL certificate for HTTPS (see [Section 2.2](#22-ssl-certificate-acm))
- **`hosted_zone/`**: Route53 hosted zone for DNS management (see [Section 2.3](#23-route-53-hosted-zone))

**Key Characteristic:** These modules are not specific to EKS - the same modules are also used in the ECS implementation (`infra-ecs/`), providing shared infrastructure across both approaches.

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
**Module Location**: `infra-eks/modules/ecr/` <br>
**Deployment Location**: `infra-eks/deployment/ecr/`

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
4. Validated certificate ARN becomes available for Ingress attachment

**Module Location**: `infra-eks/modules/ssl/` <br>
**Deployment Location**: `infra-eks/deployment/ssl/`

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

**Module Location**: `infra-eks/modules/hosted_zone/` <br>
**Deployment Location**: `infra-eks/deployment/hosted_zone/`

**Note**: DNS records (A records) that point to the Application Load Balancer are created by the approach-specific routing module (see [Section 3.6](#36-routing)).

---

## 3. Application Deployment Infrastructure (EKS-Specific)

These root modules represent **EKS-specific application infrastructure** - components that are unique to the Kubernetes-based container orchestration approach. They reside under `infra-eks/deployment/app/` and implement the compute, networking, and load balancing layers specific to running containers on EKS.

**EKS-Specific Modules:**
- **`app/vpc/`**: Network infrastructure with EKS-specific subnet tags (see [Section 3.1](#31-virtual-private-cloud-vpc))
- **`app/eks_cluster/`**: Managed Kubernetes control plane (see [Section 3.2](#32-eks-cluster))
- **`app/eks_node_group/`**: Worker nodes with Auto Scaling (see [Section 3.3](#33-eks-node-group))
- **`app/aws_lb_controller/`**: Helm chart for ALB management via Ingress (see [Section 3.4](#34-aws-load-balancer-controller))
- **`app/k8s_app/`**: Kubernetes Deployment, Service, Ingress, HPA (see [Section 3.5](#35-kubernetes-application-deployment))
- **`app/routing/`**: Route 53 A records pointing to ALB created by Ingress (see [Section 3.6](#36-routing))

**Key Characteristic:** These modules implement Kubernetes-specific concepts (clusters, node groups, pods, ingress controllers) and would be replaced by different modules in the ECS implementation (ECS clusters, services, tasks).

The following subsections provide detailed explanations of each infrastructure component, organized by category.

---

### 3.1. Virtual Private Cloud (VPC)

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

### 3.2. EKS Cluster

**Purpose**: Provides the managed Kubernetes control plane (API server, etcd, scheduler, controller manager).

**Key Components**:

#### a) EKS Cluster Resource
- **Managed Control Plane**: AWS manages the Kubernetes control plane components across multiple AZs
- **API Endpoint**: Can be public, private, or both (default: public for easier access during development)
- **Kubernetes Version**: Configurable (default: latest stable version)
- **Logging**: Optional CloudWatch logging for audit, API, authenticator, controller manager, and scheduler logs

#### b) OIDC Provider
- **IAM Roles for Service Accounts (IRSA)**: Enables Kubernetes service accounts to assume IAM roles
- **Purpose**: Allows pods to access AWS services without storing credentials
- **Use Cases**: AWS Load Balancer Controller, external-dns, cluster-autoscaler, application pods needing AWS API access

**Key Configuration**:
```hcl
endpoint_public_access = true  # API server accessible from internet
endpoint_private_access = true # API server accessible from VPC
```

**Naming Convention**: `${environment}-${project_name}-eks-cluster` <br>
**Module Location**: `infra-eks/modules/eks_cluster/` <br>
**Deployment Location**: `infra-eks/deployment/app/eks_cluster/`

**IAM Role and Security Group Details**: See [Section 3.7: IAM Roles and Policies](#37-iam-roles-and-policies) and [Section 3.8: Security Groups](#38-security-groups).

---

### 3.3. EKS Node Group

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

**IAM Role Details**: See [Section 3.7: IAM Roles and Policies](#37-iam-roles-and-policies).

---

### 3.4. AWS Load Balancer Controller

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

#### b) Controller Functionality
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

**IAM Role for Service Account (IRSA) Details**: See [Section 3.7: IAM Roles and Policies](#37-iam-roles-and-policies).

---

### 3.5. Kubernetes Application Deployment

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

#### Alternative Approach: Raw Kubernetes Manifests

**Note**: This project uses Terraform's native Kubernetes provider to manage all Kubernetes resources (Deployment, Service, Ingress, HPA) as infrastructure-as-code. This approach provides several advantages:
- **Single Tool**: All infrastructure managed through Terraform
- **State Management**: Terraform tracks all resource states consistently
- **Dependency Management**: Automatic dependency resolution between resources
- **Remote State Integration**: Seamless integration with other Terraform-managed resources (ECR, ACM certificates, VPC)

An alternative approach exists where Kubernetes resources are defined as raw YAML manifests (e.g., `deployment.yaml`, `service.yaml`, `ingress.yaml`, `hpa.yaml`) and applied using `kubectl apply -f`. While this is a common pattern in Kubernetes deployments, **it is out of scope for this project** as we prioritize infrastructure consistency and unified tooling through Terraform.

---

### 3.6. Routing

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

### 3.7. IAM Roles and Policies

The infrastructure uses multiple IAM roles for different levels of authorization in the EKS ecosystem. This section consolidates all IAM roles used across EKS infrastructure components.

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

**Trust Relationship**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

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

**Trust Relationship**:
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

**Why This Matters**: IRSA allows the Load Balancer Controller pods to automatically obtain temporary AWS credentials without embedding static credentials in the pod. The OIDC provider validates the Kubernetes service account token and allows the pod to assume the IAM role.

**Module Location**: `infra-eks/modules/aws_lb_controller/iam.tf`

---

### 3.8. Security Groups

Security Groups act as virtual firewalls, controlling network traffic at the resource level. EKS uses multiple security groups to secure different components of the infrastructure.

#### a) EKS Cluster Security Group

**Attached To**: EKS control plane

**Purpose**: Controls communication between the Kubernetes control plane and worker nodes.

**Ingress Rules**:
| Port | Protocol | Source | Description |
|------|----------|--------|-------------|
| 443 | TCP | Worker node security group | HTTPS from worker nodes for kubectl commands |

**Egress Rules**:
| Port | Protocol | Destination | Description |
|------|----------|-------------|-------------|
| 1025-65535 | TCP | Worker node security group | Control plane to worker node communication |
| All | All | 0.0.0.0/0 | Allow all outbound (AWS API calls) |

**Module Location**: `infra-eks/modules/eks_cluster/security_groups.tf`

---

#### b) EKS Worker Nodes Security Group

**Attached To**: EC2 worker nodes in the node group

**Purpose**: Controls network access to worker nodes running Kubernetes pods.

**Ingress Rules**:
| Port | Protocol | Source | Description |
|------|----------|--------|-------------|
| 1025-65535 | TCP | Cluster security group | Communication from control plane |
| All | All | Self (node-to-node) | Inter-node communication for pods |
| 30000-32767 | TCP | ALB security group (optional) | NodePort range for ALB to reach pods |

**Egress Rules**:
| Port | Protocol | Destination | Description |
|------|----------|-------------|-------------|
| All | All | 0.0.0.0/0 | Allow all outbound (NAT Gateway, AWS APIs, ECR, internet) |

**Why This Matters**:
- **NodePort Range (30000-32767)**: When using `target-type: ip` in Ingress, this rule may not be needed as ALB registers pod IPs directly. However, if using `target-type: instance`, ALB routes traffic to NodePort services.
- **Inter-node Communication**: Pods need to communicate across nodes for distributed applications and service mesh implementations.

**Module Location**: `infra-eks/modules/eks_node_group/security_groups.tf`

---

#### c) Application Load Balancer Security Group

**Attached To**: Application Load Balancer (created automatically by AWS Load Balancer Controller)

**Purpose**: Controls public internet access to the load balancer.

**Ingress Rules**:
| Port | Protocol | Source | Description |
|------|----------|--------|-------------|
| 443 | TCP | 0.0.0.0/0 | HTTPS traffic from internet |
| 80 | TCP | 0.0.0.0/0 | HTTP traffic (redirects to HTTPS) |

**Egress Rules**:
| Port | Protocol | Destination | Description |
|------|----------|-------------|-------------|
| All | All | Worker node security group | Outbound to pods (when using target-type: ip) |
| All | All | 0.0.0.0/0 | Allow all outbound traffic |

**Note**: The ALB security group is created automatically by the AWS Load Balancer Controller when an Ingress resource is deployed. The controller configures the appropriate ingress/egress rules based on Ingress annotations.

**Creation Mechanism**: AWS Load Balancer Controller dynamically creates and manages this security group via Kubernetes Ingress annotations.

---

**Return to:** [Main README](../README.md) | [Prerequisites and Setup](PREREQUISITES_AND_SETUP.md) | [CI/CD Workflows](CICD_WORKFLOWS.md)
