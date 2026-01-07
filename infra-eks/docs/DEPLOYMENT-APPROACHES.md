# Kubernetes Deployment Approaches: YAML vs Terraform

This document explains the deployment approach used in this project and mentions an alternative approach for context.

## Overview

This repository uses **Terraform with the Kubernetes provider** ([modules/k8s_app/](../modules/k8s_app/)) to deploy Kubernetes resources as infrastructure-as-code.

An alternative approach exists where Kubernetes resources are defined as raw YAML manifests and applied using `kubectl`, but **this approach is out of scope for this project** as we prioritize unified tooling and infrastructure consistency through Terraform.

## The Terraform Approach (Used in This Project)

**Location:**
- Module: [modules/k8s_app/](../modules/k8s_app/)
- Deployment: [deployment/app/k8s_app/](../deployment/app/k8s_app/)

**Module Files:**
- [main.tf](../modules/k8s_app/main.tf) - Kubernetes Deployment resource
- [service.tf](../modules/k8s_app/service.tf) - Kubernetes Service resource
- [ingress.tf](../modules/k8s_app/ingress.tf) - Kubernetes Ingress resource
- [hpa.tf](../modules/k8s_app/hpa.tf) - HPA resource
- [vars.tf](../modules/k8s_app/vars.tf) - Input variables
- [outputs.tf](../modules/k8s_app/outputs.tf) - Module outputs
- [locals.tf](../modules/k8s_app/locals.tf) - Common tags and labels
- [versions.tf](../modules/k8s_app/versions.tf) - Provider versions

**Deployment Method:**
```bash
cd infra-eks/deployment/app/k8s_app
terraform init
terraform apply
```

**Advantages:**
- ✅ **Unified Terraform workflow** for infrastructure + applications
- ✅ **Automatic integration** with Terraform remote state (ECR, ACM, VPC, EKS)
- ✅ **Environment-specific variables** and configurations
- ✅ **Type safety and validation** through Terraform
- ✅ **Automatic value substitution** (ECR URL, certificate ARN) from remote state
- ✅ **Infrastructure and application managed together** in one tool
- ✅ **Consistent tagging** across all resources
- ✅ **Dependency management** - Terraform ensures correct deployment order
- ✅ **State tracking** - All resources tracked in Terraform state

**Prerequisites:**
1. EKS cluster deployed
2. EKS node group deployed
3. AWS Load Balancer Controller installed
4. ACM certificate validated
5. ECR repository with Docker image

**Example Workflow:**
```bash
# All steps use Terraform for consistency
cd infra-eks/deployment/app/eks_cluster
terraform apply

cd ../eks_node_group
terraform apply

cd ../aws_lb_controller
terraform apply

cd ../k8s_app
terraform apply

# Verify deployment
kubectl get deployments
kubectl get services
kubectl get ingress
kubectl get hpa
```

## Alternative Approach: Raw YAML Manifests (Out of Scope)

An alternative deployment pattern in the Kubernetes ecosystem uses raw YAML manifest files (e.g., `deployment.yaml`, `service.yaml`, `ingress.yaml`, `hpa.yaml`) that are applied directly using `kubectl apply -f`.

**Characteristics:**
- Pure Kubernetes-native approach
- Uses standard `kubectl` CLI
- GitOps-friendly (ArgoCD, FluxCD)
- Industry standard in Kubernetes-native organizations
- Portable across cloud providers
- Requires manual value replacement for cloud-specific resources
- No automatic integration with infrastructure provisioning
- Separate deployment workflow from infrastructure

**Why This Project Uses Terraform Instead:**

1. **Unified Tooling**: Managing both infrastructure (VPC, EKS, ALB) and applications (Deployments, Services) with a single tool reduces operational complexity
2. **Automatic Integration**: Terraform remote state allows seamless passing of values between infrastructure layers without manual intervention
3. **Type Safety**: Terraform provides validation and type checking before deployment
4. **Dependency Management**: Terraform automatically handles dependencies between resources
5. **Consistent State Management**: All infrastructure tracked in one place
6. **Environment Configuration**: Easy to manage dev/prod differences through Terraform variables

## Comparison Table

| Aspect | Terraform Approach (This Project) | YAML Manifests Approach (Out of Scope) |
|--------|-----------------------------------|----------------------------------------|
| **Tool** | Terraform with Kubernetes provider | kubectl + YAML files |
| **State Management** | Terraform state tracks all resources | No state (imperative) |
| **Value Injection** | Automatic from remote state | Manual replacement required |
| **Integration** | Seamless with infrastructure | Separate from infrastructure |
| **Learning Curve** | Requires Terraform knowledge | Standard Kubernetes |
| **GitOps** | Requires additional tooling | Native GitOps support |
| **Use Case** | Unified infrastructure + apps | Kubernetes-native teams |
| **Industry Adoption** | Common in DevOps/Platform teams | Common in K8s-focused orgs |

## Conclusion

This project prioritizes **infrastructure consistency and unified tooling** by using Terraform for all resources, including Kubernetes application deployments. While the YAML manifests approach is widely used in Kubernetes-native organizations, the Terraform approach better aligns with this project's goals of managing complete infrastructure as code with a single tool.

For teams that prefer Kubernetes-native workflows, the YAML manifest approach remains a valid alternative pattern, but implementing it is beyond the scope of this learning project.
