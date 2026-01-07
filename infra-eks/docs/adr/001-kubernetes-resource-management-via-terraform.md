# ADR 001: Kubernetes Resource Management via Terraform

## Status
Accepted

## Context

When deploying applications to Kubernetes, there are two primary approaches for managing Kubernetes resources (Deployments, Services, Ingresses, HPAs):

1. **Terraform with Kubernetes Provider**: Define Kubernetes resources as Terraform configuration
2. **Raw YAML Manifests with kubectl**: Define Kubernetes resources as YAML files and apply them using `kubectl apply -f`

Both approaches are valid and widely used in the industry. This decision impacts:
- Developer workflow and tooling consistency
- Infrastructure state management and drift detection
- Integration with other infrastructure components (VPC, EKS cluster, ECR, ACM certificates)
- Deployment automation and CI/CD pipelines
- Team skills and learning curve
- Multi-environment configuration management

### Current Infrastructure Context

This project deploys a NestJS application to AWS EKS with the following components:
- **Foundational Infrastructure** (Terraform-managed): VPC, EKS cluster, node groups, ECR, ACM certificates, Route53
- **Application Resources** (needs decision): Kubernetes Deployment, Service, Ingress, HPA

The foundational infrastructure is already defined in Terraform, creating tight integration with AWS resources through remote state.

### Industry Patterns

**Terraform Approach:**
- Common in organizations with strong infrastructure-as-code practices
- Preferred by platform/DevOps teams managing both infrastructure and applications
- Used when unified state management is valued
- Popular in environments with heavy Terraform investment

**YAML Manifests Approach:**
- Standard in Kubernetes-native organizations
- Preferred by application teams with Kubernetes expertise
- Used with GitOps tools (ArgoCD, FluxCD)
- Common in cloud-agnostic or multi-cluster environments

## Decision

We will use **Terraform with the Kubernetes provider** to manage all Kubernetes application resources (Deployment, Service, Ingress, HPA).

### Implementation Details

**Location:** `infra-eks/modules/k8s_app/`

**Module Files:**
- `main.tf` - Kubernetes Deployment resource
- `service.tf` - Kubernetes Service resource
- `ingress.tf` - Kubernetes Ingress resource
- `hpa.tf` - Horizontal Pod Autoscaler resource
- `vars.tf` - Input variables
- `outputs.tf` - Module outputs
- `locals.tf` - Common tags and labels
- `versions.tf` - Provider versions

**Deployment Method:**
```bash
cd infra-eks/deployment/app/k8s_app
terraform init
terraform apply
```

**Provider Configuration:**
```hcl
provider "kubernetes" {
  host                   = data.terraform_remote_state.eks_cluster.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks_cluster.outputs.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks_cluster.outputs.cluster_id]
  }
}
```

## Alternatives Considered

### Alternative 1: Raw YAML Manifests with kubectl (Not Implemented)

**Description:** Define Kubernetes resources as YAML files (e.g., `deployment.yaml`, `service.yaml`, `ingress.yaml`, `hpa.yaml`) and apply them using `kubectl apply -f manifest.yaml`.

**Typical Structure:**
```
kubernetes/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── hpa.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml
    └── prod/
        └── kustomization.yaml
```

**Deployment Method:**
```bash
kubectl apply -k kubernetes/overlays/prod
```

**Pros:**
- ✅ **Kubernetes Native**: Standard approach in Kubernetes community
- ✅ **GitOps Friendly**: Works seamlessly with ArgoCD, FluxCD
- ✅ **Portability**: YAML manifests work across any Kubernetes cluster (cloud-agnostic)
- ✅ **Declarative**: Pure Kubernetes declarative syntax
- ✅ **Rich Ecosystem**: kubectl plugins, Kustomize, Helm integration
- ✅ **Team Skills**: Many teams have existing Kubernetes YAML expertise
- ✅ **Debugging**: Standard `kubectl` commands for troubleshooting
- ✅ **Community Patterns**: Well-documented patterns and examples

**Cons:**
- ❌ **No State Management**: Imperative application, no drift detection
- ❌ **Manual Value Replacement**: Must manually replace values like ECR image URL, certificate ARN
- ❌ **Separate Workflow**: Different deployment process from infrastructure
- ❌ **No Remote State Integration**: Cannot automatically reference Terraform outputs
- ❌ **No Type Validation**: YAML validation is less robust than Terraform HCL
- ❌ **Environment Management**: Requires Kustomize or Helm for env-specific configs
- ❌ **No Automatic Dependencies**: Must manually coordinate with infrastructure deployment
- ❌ **Tooling Fragmentation**: kubectl + terraform = two tool chains

**Example YAML Approach:**
```yaml
# deployment.yaml (requires manual value substitution)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nestjs-app
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: nestjs-app
        image: "123456789012.dkr.ecr.eu-west-1.amazonaws.com/prod-myapp:prod-abc123"  # Must be manually updated
        ports:
        - containerPort: 3000
---
# ingress.yaml (requires manual certificate ARN substitution)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nestjs-app-ingress
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:..."  # Must be manually updated
spec:
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

**Verdict:** Rejected - Value substitution complexity and lack of integration with Terraform-managed infrastructure outweigh Kubernetes-native benefits

### Alternative 2: Terraform + Helm Provider

**Description:** Use Terraform to deploy Helm charts, combining Terraform state management with Helm's templating capabilities.

**Pros:**
- ✅ Terraform state management
- ✅ Helm templating for complex apps
- ✅ Access to Helm chart ecosystem

**Cons:**
- ❌ Additional abstraction layer (Terraform → Helm → Kubernetes)
- ❌ Learning curve for Helm charts
- ❌ Overkill for simple application deployment
- ❌ Helm release management adds complexity

**Verdict:** Rejected - Unnecessary complexity for a single application

### Alternative 3: Hybrid Approach (Terraform Infrastructure + YAML Applications)

**Description:** Use Terraform for infrastructure (VPC, EKS, node groups) but YAML manifests for application resources.

**Pros:**
- ✅ Separates infrastructure and application concerns
- ✅ Allows different teams to own infrastructure vs applications
- ✅ Kubernetes-native app deployment

**Cons:**
- ❌ Fragmented tooling (two deployment methods)
- ❌ No automatic integration between layers
- ❌ Must manually pass values (ECR URL, certificate ARN) between Terraform and YAML
- ❌ State management inconsistency

**Verdict:** Rejected - Tooling fragmentation outweighs separation of concerns benefit

### Alternative 4: CDK for Terraform (CDKTF)

**Description:** Use CDK for Terraform to define both infrastructure and Kubernetes resources in a programming language (TypeScript, Python).

**Pros:**
- ✅ Programming language features (loops, conditionals, functions)
- ✅ Type safety
- ✅ Unified language for infrastructure and application logic

**Cons:**
- ❌ Additional abstraction layer
- ❌ Less mature than native Terraform
- ❌ Smaller community and fewer examples
- ❌ Debugging complexity

**Verdict:** Rejected - Additional complexity not justified for this project

## Rationale

### Why Terraform Kubernetes Provider?

**1. Unified Infrastructure-as-Code Workflow**
- Single tool (Terraform) manages entire stack: AWS infrastructure → Kubernetes cluster → application deployment
- Consistent `terraform plan` → `terraform apply` workflow
- Single CI/CD pipeline for all infrastructure layers
- Reduces cognitive load and tool switching

**2. Automatic Integration with AWS Resources**
Terraform remote state enables seamless value passing:

```hcl
# Automatic integration without manual substitution
module "k8s_app" {
  source = "../../../modules/k8s_app"

  ecr_app_image       = data.terraform_remote_state.ecr.outputs.ecr_repository_url
  certificate_arn     = data.terraform_remote_state.ssl.outputs.certificate_arn
  vpc_id              = data.terraform_remote_state.vpc.outputs.vpc_id
  cluster_name        = data.terraform_remote_state.eks_cluster.outputs.cluster_id
  alb_security_groups = data.terraform_remote_state.vpc.outputs.alb_security_group_ids
}
```

**No manual value substitution required** - values flow automatically from infrastructure outputs to application inputs.

**3. State Management and Drift Detection**
- Terraform state tracks all Kubernetes resources
- `terraform plan` shows exactly what will change
- Detects manual changes made via `kubectl`
- Enables rollback to known-good state
- GitOps-style declarative management with state tracking

**4. Type Safety and Validation**
- HCL provides better type validation than YAML
- Terraform validates configuration before applying
- IDE support with autocomplete and error checking
- Catches errors at plan time, not apply time

**5. Environment Configuration**
- Environment-specific values via tfvars files
- Variable validation ensures correct types and constraints
- No need for Kustomize overlays or Helm values files

Example:
```hcl
variable "replicas" {
  type = map(number)
  default = {
    dev  = 2
    prod = 3
  }
}

variable "cpu_request" {
  type = map(string)
  default = {
    dev  = "50m"
    prod = "250m"
  }
}
```

**6. Dependency Management**
Terraform automatically handles dependencies:
- EKS cluster must exist before deploying apps
- Node group must be ready before scheduling pods
- ECR image must be pushed before creating Deployment
- Certificate must be validated before creating Ingress

**7. Consistent Tagging and Cost Allocation**
- AWS provider `default_tags` propagate to all resources
- Kubernetes labels can reference Terraform variables
- Consistent tagging strategy across infrastructure and applications

### Project-Specific Considerations

**This is a Learning Project:**
- Goal: Demonstrate Infrastructure as Code best practices
- Terraform-first approach provides unified learning experience
- Students learn one tool deeply vs multiple tools shallowly

**Single Application:**
- Simple deployment (one Deployment, Service, Ingress, HPA)
- Helm or complex YAML templating not needed
- Terraform Kubernetes provider handles this elegantly

**Tight AWS Integration:**
- ECR image URLs must reference Terraform-created ECR repository
- Ingress annotations require ACM certificate ARN from Terraform
- ALB created by Ingress controller needs proper subnet tags (set by Terraform)

## Consequences

### Positive

1. **Unified Tooling**
   - One tool (Terraform) for everything
   - Single state management approach
   - Consistent deployment workflow
   - Simplified CI/CD pipelines

2. **Automatic Value Propagation**
   - No manual substitution of ECR URLs, certificate ARNs, VPC IDs
   - Remote state automatically connects infrastructure layers
   - Reduces human error in configuration

3. **State Tracking**
   - Terraform state tracks all Kubernetes resources
   - Drift detection via `terraform plan`
   - Rollback capability to previous state
   - Audit trail of all changes

4. **Type Safety**
   - HCL validation catches errors before deployment
   - IDE autocomplete and error checking
   - Better developer experience than YAML

5. **Dependency Management**
   - Terraform handles deployment order automatically
   - No need for manual wait steps
   - Reduces deployment failures from ordering issues

6. **Environment Management**
   - Simple tfvars files for dev vs prod
   - No need for Kustomize or Helm
   - Clear environment-specific configuration

### Negative

1. **Kubernetes Community Disconnect**
   - Most Kubernetes documentation uses YAML examples
   - Harder to adapt community examples to Terraform
   - Smaller community of Terraform Kubernetes provider users
   - **Mitigation:** Project includes comprehensive examples

2. **Abstraction Layer**
   - Terraform HCL wraps Kubernetes resources
   - Must understand both Terraform and Kubernetes concepts
   - Debugging requires knowledge of both layers
   - **Mitigation:** Clear documentation and examples provided

3. **Tool Dependency**
   - Locked into Terraform for Kubernetes resource management
   - Migration to GitOps (ArgoCD) would require conversion to YAML
   - **Mitigation:** Acceptable for this project's scope

4. **kubectl Limitations**
   - Some kubectl commands require YAML (e.g., `kubectl apply -f -`)
   - Cannot use `kubectl edit` to modify resources managed by Terraform
   - **Mitigation:** Use `terraform apply` for all changes

5. **Learning Curve**
   - Team must learn both Terraform and Kubernetes
   - Not purely Kubernetes-native workflow
   - **Mitigation:** This is a learning project - broader exposure is beneficial

### Neutral

1. **Provider Maturity**
   - Terraform Kubernetes provider is mature and stable
   - Active maintenance by HashiCorp
   - Good coverage of Kubernetes resources

2. **GitOps Compatibility**
   - Terraform workflows can be GitOps-style (Git as source of truth)
   - Not as seamless as ArgoCD with YAML, but achievable
   - Terraform Cloud provides similar reconciliation loop

3. **Multi-Cluster Management**
   - Terraform can manage multiple Kubernetes clusters
   - Requires separate provider configs per cluster
   - YAML approach is slightly more portable

## Implementation

### Prerequisites

1. **EKS Cluster Deployed**
   - Cluster must exist with worker nodes
   - AWS Load Balancer Controller must be installed
   - Node groups must be in ACTIVE state

2. **AWS Resources Created**
   - ECR repository with pushed Docker image
   - ACM certificate validated
   - VPC with proper EKS subnet tags

3. **kubeconfig Configured**
   - `aws eks update-kubeconfig --name ${CLUSTER_NAME}`
   - Terraform Kubernetes provider uses AWS CLI for authentication

### Deployment Stages

**Stage 1: VPC and EKS Cluster**
```bash
cd infra-eks/deployment/app/vpc && terraform apply
cd ../eks_cluster && terraform apply
cd ../eks_node_group && terraform apply
```

**Stage 2: AWS Load Balancer Controller**
```bash
cd ../aws_lb_controller && terraform apply
```

**Stage 3: Kubernetes Application (Terraform Kubernetes Provider)**
```bash
cd ../k8s_app && terraform apply
```

Terraform creates:
- Kubernetes Deployment with pod spec
- Kubernetes Service (ClusterIP)
- Kubernetes Ingress (creates ALB via controller)
- Horizontal Pod Autoscaler

**Stage 4: Routing**
```bash
cd ../routing && terraform apply
```

Creates Route53 A record pointing to ALB created by Ingress.

### Verification

```bash
# Check resources via Terraform
terraform output

# Check resources via kubectl
kubectl get deployments
kubectl get services
kubectl get ingress
kubectl get hpa

# Check pods
kubectl get pods -l app=nestjs-app

# Test application
curl https://yourdomain.com
```

## Monitoring and Maintenance

### Day-to-Day Operations

**Updating Application:**
```bash
# Update image tag in terraform.tfvars
ecr_app_image = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/prod-myapp:prod-xyz789"

# Apply changes
terraform apply

# Terraform triggers rolling update
kubectl rollout status deployment/nestjs-app
```

**Scaling Application:**
```bash
# Update replica count in vars.tf
variable "replicas" {
  default = { dev = 3, prod = 5 }
}

# Apply changes
terraform apply
```

**Viewing Logs:**
```bash
kubectl logs -l app=nestjs-app --tail=100 -f
```

### Troubleshooting

**Deployment Issues:**
```bash
# Check pod status
kubectl describe pod <pod-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check Terraform state
terraform show
```

**Ingress/ALB Issues:**
```bash
# Check Ingress status
kubectl describe ingress nestjs-app-ingress

# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check ALB in AWS Console
aws elbv2 describe-load-balancers
```

## Future Considerations

### Potential Migration to GitOps

If the team wants to adopt ArgoCD or FluxCD in the future:

**Option 1: Convert Terraform to YAML**
- Use `terraform show -json` to extract configuration
- Convert HCL to YAML manifests
- Set up ArgoCD/FluxCD sync

**Option 2: Terraform + GitOps Hybrid**
- Keep infrastructure in Terraform
- Move application resources to YAML
- ArgoCD manages application layer

**Migration Complexity:** Moderate - requires YAML conversion and GitOps setup

### Potential Addition of Helm

If multiple applications need deployment:

**Option 1: Terraform Helm Provider**
- Use `helm_release` resource
- Maintain Terraform workflow
- Access Helm chart ecosystem

**Option 2: Helm CLI**
- Separate Helm deployment from Terraform
- Use Helm for app-level concerns

## References

- **Terraform Documentation:**
  - [Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
  - [Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)

- **Kubernetes Documentation:**
  - [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
  - [Services](https://kubernetes.io/docs/concepts/services-networking/service/)
  - [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
  - [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)

- **AWS Documentation:**
  - [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
  - [EKS Best Practices - GitOps](https://aws.github.io/aws-eks-best-practices/gitops/)

- **Project Documentation:**
  - [k8s_app Module](../../modules/k8s_app/) - Terraform Kubernetes resource definitions
  - [EKS Infrastructure Documentation](../../README.md) - Complete EKS setup guide

## Revision History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-01-07 | 1.0 | Claude | Initial ADR documenting decision to use Terraform Kubernetes provider over YAML manifests for application deployment |

## Notes

This ADR documents the **Terraform-first approach** for Kubernetes resource management, chosen for:
1. ✅ **Unified tooling** - One tool for infrastructure + applications
2. ✅ **Automatic integration** - Remote state connects all layers
3. ✅ **State management** - Drift detection and rollback capability
4. ✅ **Learning value** - Comprehensive IaC experience in learning project

**Key Trade-off:** Sacrifices Kubernetes-native patterns (YAML, kubectl, GitOps) for infrastructure consistency and automation benefits.

**Alternative Viability:** The YAML manifests approach is equally valid for teams with strong Kubernetes expertise or multi-cloud requirements. This decision prioritizes infrastructure-as-code consistency over Kubernetes community patterns.

**For Kubernetes-Native Teams:** If your organization has strong Kubernetes expertise and prefers GitOps workflows, consider using YAML manifests with ArgoCD/FluxCD instead of this Terraform approach. Both are production-ready patterns.
