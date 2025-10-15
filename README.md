# AWS High-Availability App with Terraform

## Table of Contents

1. [Motivation & Goals](#1-motivation--goals)
2. [Application Overview](#2-application-overview)
3. [AWS Infrastructure Architecture](#3-aws-infrastructure-architecture)
    * [3.1. Project Structure: Modules and Reusability](#3-a-project-structure-modules-and-reusability)
    * [3.2. Core AWS Components](#3-b-core-aws-components)
    * [3.3. Infrastructure Diagram](#3-c-infrastructure-diagram)
    * [3.4. Security and Access Permissions](#3-d-security-and-access-permissions)
4. [Environment Configuration Differences](#4-environment-configuration-differences)
5. [CI/CD Workflows (GitHub Actions)](#5-cicd-workflows-github-actions-)
    * [5.1. Deployment Prerequisites and Initial Setup](#5-a-deployment-prerequisites-and-initial-setup)
    * [5.2. Full Infrastructure Deployment](#5-b-full-infrastructure-deployment)
    * [5.3. Infrastructure Teardown](#5-c-infrastructure-teardown)

## 1. Motivation & Goals

This project was built as a practical, hands-on learning experience to master **Terraform** and **AWS** for cloud infrastructure deployment. The primary goals are:

* To learn **Infrastructure as Code (IaC)** by defining all cloud resources using **Terraform**.
* To create reusable Terraform modules to quickly spin up **simple yet production-ready AWS infrastructure** that ensures **high availability**.
* To deploy a sample monolithic application (a "Hello World" NestJS API) on **AWS Elastic Container Service (ECS)**, configured with auto-scaling and a **secure HTTPS endpoint**.

---

## 2. Application Overview

The application deployed to ECS is a minimal **NestJS API**.

| Endpoint | Description |
| :--- | :--- |
| `/` (GET) | The primary endpoint, which returns `"Hello World!"`.
| `/health` (GET) | The health check endpoint, which returns `true`. It logs a unique instance ID for diagnostics and is used by the ALB's Target Group to monitor container health.

The application's **Dockerfile** uses the official Node.js Alpine image, installs `pnpm` globally, and runs the compiled application via `pnpm start:prod` on port **3000**.

---

## 3. AWS Infrastructure Architecture

The deployment creates a highly available architecture using interconnected AWS services. All resources are consistently tagged with **`Project = high-availability-app`** for easy location and management via AWS Resource Explorer.

### 3.1. Project Structure: Modules and Reusability

The project utilizes a clear separation between **Root Modules** (deployment stages) and **Child Modules** (reusable components) to enforce the Single Responsibility Principle (SRP) and maximize reusability.

* **Child Modules (`infra/modules/*`):** These define single, reusable components of infrastructure (e.g., `ecr`, `alb`, `ecs_cluster`, `ssl`).
    * **Goal:** High **reusability** and **Separation of Concerns (SoC)**. A team can easily reuse the `alb` module in another project without needing to copy VPC or ECS code.
    * **Implementation:** They rely solely on input variables (like `var.vpc_id`) and return outputs (like `alb_dns_name`).
* **Root Modules (`infra/deployment/*`):** These define the environment-specific deployment stages (e.g., `prod/vpc`, `prod/ecs_service`).
    * **Goal:** **Orchestration** and **Configuration**. They stitch the child modules together, using `data "terraform_remote_state"` to read outputs from previous stages (like VPC ID) and pass environment-specific values (like `prod` scaling limits) to the child modules.

### 3.2. Core AWS Components

| AWS Service | Role in the Architecture |
| :--- | :--- |
| **Virtual Private Cloud (VPC)** | Provides an isolated network, defining public and private subnets across multiple AZs for high availability. NAT Gateways enable private resources to access the internet. |
| **Elastic Container Registry (ECR)** | A private Docker registry storing application container images. Uses priority rules (Rule 1: untagged, Rule 2: tagged) to aggressively expire images while safely retaining a configurable count of environment-tagged (`dev-`, `prod-`) images. |
| **ECS Cluster** | The compute capacity (EC2 instances) running within private subnets. It uses an Auto Scaling Group (ASG) and a Capacity Provider who tells the ECS how to manage the ASG scaling. A critical element in the cluster is the ECS Control Plane, the central component that coordinates containers (i.e., tasks) and ensures cluster wellbeing. Furthermore, each EC2 instance includes an ECS Agent that reports containers health to the Control Plane. |
| **ECS Service** | The deployment mechanism that defines how many copies of a specific task definition should run on a given ECS cluster, automatically maintaining that desired count and integrating with an Elastic Load Balancer for traffic distribution. |
| **ECS Task** | The fundamental unit of deployment (the running container). Deployed onto EC2 instances, tasks receive a private IP via `awsvpc` networking and are registered with the ALB Target Group. |
| **Application Load Balancer (ALB)** | Distributes incoming traffic. It listens on Port 443 (HTTPS) and redirects all Port 80 (HTTP) traffic to HTTPS (301 Permanent Redirect). The ALB forwards traffic to an ALB Target Group, which acts as the dynamic list of healthy ECS Tasks. |
| **Route 53 & ACM** | The Route 53 Hosted Zone manages DNS records. AWS Certificate Manager (ACM) provides and validates the SSL certificate, which is attached to the ALB's HTTPS listener to enable secure communication. |

### 3.3. Infrastructure Diagram

![Alt text](aws_infrastructure.svg "AWS Infrastructure")

### 3.4. Security and Access Permissions

The infrastructure uses a robust, layered security model based on IAM roles (for access control between AWS services) and Security Groups (for network traffic filtering).

#### IAM Roles (Service-to-Service Authorization)

* **ECS EC2 Instance Role (`ecs_instance_role`):** This role is assumed by the EC2 container instances. Its permissions allow the instance to:
    * **Join the Cluster:** Register itself as a Container Instance with the ECS Control Plane (`ecs:RegisterContainerInstance`).
    * **Pull Images:** Get authorization tokens from ECR to pull Docker images (`ecr:GetAuthorizationToken`, `ecr:BatchGetImage`, etc.).
    * **Logging:** Write operational logs to AWS CloudWatch Logs.
    * **SSM Access:** Includes the managed policy `AmazonSSMManagedInstanceCore` to enable secure remote access to the EC2 instances via AWS Session Manager (SSM).
* **ECS Task Execution Role (`ecs_task_execution_role`):** This role is assumed by the ECS service itself. It provides the permissions needed for the ECS agent to perform actions on behalf of your tasks, specifically:
    * **Image Pull:** Pull the required Docker image from ECR.
    * **Log Management:** Write container application logs to the designated CloudWatch Log Group (`my-app-lg`).

#### Security Groups (Network Traffic Filtering)

The network model is secured by isolating the application tier within the private subnets and restricting access based on the least-privilege principle.

* **Application Load Balancer SG (`alb-sg`):**
    * **Ingress:** Allows inbound traffic from `0.0.0.0/0` (the entire internet) on **Port 80 (HTTP)** and **Port 443 (HTTPS)**. This is the public entry point.
    * **Egress:** Allows all outbound traffic (`0.0.0.0/0` on all ports/protocols). This is critical as it enables the ALB to initiate the connection to the backend ECS tasks.
* **ECS Tasks SG (`ecs-tasks-sg`):**
    * **Ingress:** **Highly Restricted.** Allows incoming traffic *only* on the application's container port (`3000`) and only when the source is the **`alb-sg`**. This prevents direct internet access to the containers.
    * **Egress:** Allows all outbound traffic (`0.0.0.0/0`), enabling tasks to pull dependencies and access other necessary AWS services like the NAT Gateway.
* **ECS Cluster SG (`cluster-sg`):** This is associated with the underlying EC2 instances. It ensures the instances themselves can communicate and perform necessary management functions.
    * **Egress:** Allows all outbound traffic (`0.0.0.0/0`) for tasks like instance patching, running the ECS Agent, and pulling images.

---

## 4. Environment Configuration Differences

The Terraform code supports configuration differences between `dev` and `prod` environments, driven by environment-specific variable lookups.

| Setting | `dev` Value | `prod` Value | Motivation |
| :--- | :--- | :--- | :--- |
| **VPC NAT Gateway** | `true` (Single) | `false` (Multiple) | Cost-saving in `dev`; multiple NAT GWs in `prod` ensure **high-availability**. |
| **ECR Tagged Image Retention** | Retains max 3 tagged images. | Retains max 10 tagged images. | Minimizes `dev` ECR size; keeps a deeper history for production rollbacks. Untagged images are cleaned up aggressively in both environments. |
| **Min/Max EC2 Instances (ASG)** | 1 / 2 | 2 / 4 | Smaller, cheaper cluster in `dev`; larger cluster in `prod` for baseline capacity and scaling safety. |
| **ECS Cluster Max Utilisation** | 100 | 75 | Allows `dev` EC2 hosts to run at full capacity; 75% in `prod` provides a buffer for immediate scaling and stability. |
| **EC2 Scale-In Protection (ASG)** | `false` | `true` | Disabled in `dev` to allow quick teardown; Enabled in `prod` to prevent the ASG from terminating instances currently hosting tasks. |
| **ECS Task Placement Strategy** | `binpack:cpu` | `spread:az`, then `spread:instanceId` | **Cost optimization** (place tasks on the fewest possible instances) in `dev`; **Maximized fault tolerance** (against single-instance failures) in `prod`. |
| **ALB Deletion Protection** | `false` | `true` | Prevents accidental deletion of the load balancer in `prod`. |
| **Route53 `force_destroy`** | `true` | `false` | Allows quick cleanup in `dev`; **Protects the production domain** from accidental deletion in `prod`. |

---

## 5. CI/CD Workflows (GitHub Actions) 🚀

All infrastructure changes are managed via GitHub Actions (GHA) workflows. The deployment is split into initial setup and main deployment due to dependencies (Route53/S3 must exist before ACM/Terraform state can use them).

### 5.1. Deployment Prerequisites and Initial Setup

To deploy this project, **you must own a domain name** accessible through an SSL certificate (e.g., `https://example.com`) and perform manual DNS updates.

1.  **Execute `deploy_hosted_zone.yaml` (Manual Trigger)**: This job calls a reusable workflow to deploy the remote **Terraform state S3 bucket** (`josumartinez-terraform-state-bucket`) and then creates the **Route53 Hosted Zone**.
2.  **Manual Action**: After the job succeeds, go to your domain hosting provider and update the **DNS name servers** to the ones provided by the new Route 53 Hosted Zone.
3.  **Wait**: Wait for DNS propagation to complete. The ACM certificate validation depends on this.

### 5.2. Full Infrastructure Deployment

Once the DNS is propagated, run the main deployment workflow (triggered on `push` to `main`):

* **`deploy_aws_infra.yaml`**: This workflow executes the deployment in a dependency-aware order:
    1. **`deploy-ecr`**: Creates the ECR repository.
    2. **`retrieve-ssl`**: Requests and validates the ACM certificate.
    3. **`build-and-push-app-docker-image-to-ecr`**: Builds the NestJS app and pushes the Docker image (tagged with `${{ env.ENVIRONMENT }}-${{ github.sha }}`) to ECR.
    4. **`deploy-vpc`**: Creates the VPC, subnets, and NAT Gateways.
    5. **`deploy-ecs-cluster`**: Creates the ECS Cluster, IAM roles, and the ASG Launch Template/Capacity Provider.
    6. **`deploy-alb`**: Creates the Application Load Balancer and its listeners (HTTPS + HTTP Redirect).
    7. **`deploy-ecs-service`**: Creates the ECS Task Definition and Service, linking to the ALB Target Group and configuring Task Auto Scaling.
    8. **`deploy-routing`**: Creates the Route 53 A records for the root and `www` domains, pointing to the ALB.

### 5.3. Infrastructure Teardown

Cleanup is also performed in an ordered, two-step workflow (both manually triggered: `workflow_dispatch`):

* **`destroy_aws_infra.yaml`**: This workflow destroys the application and its core services first:
    1. **`destroy-ecs-service`**: Scales the ECS service down to 0 tasks and waits for stability, then destroys the ECS service and its resources.
    2. **`destroy-routing`, `destroy-alb`, `destroy-ssl`, `destroy-ecs-cluster`**: Destroys resources in the reverse order of deployment.
    3. **`destroy-ecr`**: **Crucially**, it first runs an AWS CLI command to delete all images from the repository and then destroys the ECR repository resource.
    4. **`destroy-vpc`**: Destroys the VPC and networking components.

* **`destroy_hosted_zone.yaml`**: This performs the final cleanup:
    1. **`destroy-hosted-zone`**: Destroys the Route 53 Hosted Zone.
    2. **`destroy-terraform-state-bucket`**: It first deletes all objects (`aws s3 rm --recursive`) and then uses Terraform to destroy the empty S3 state bucket.