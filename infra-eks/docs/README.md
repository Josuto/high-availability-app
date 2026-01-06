# AWS EKS Infrastructure - Kubernetes Alternative to ECS

This directory contains a complete Terraform implementation for deploying your application on **AWS EKS (Elastic Kubernetes Service)** instead of ECS.

## Architecture Overview

### ECS → EKS Component Mapping

| ECS Component | EKS Equivalent | Description |
|---------------|----------------|-------------|
| **ECS Cluster** | **EKS Cluster** | Control plane for container orchestration |
| **ECS EC2 Launch Template + ASG** | **EKS Node Group** | Managed EC2 instances running Kubernetes |
| **ECS Task Definition** | **Kubernetes Deployment** | Application container specifications |
| **ECS Service** | **Kubernetes Service + Ingress** | Load balancing and service discovery |
| **ALB Target Group** | **AWS Load Balancer Controller** | Ingress controller managing ALB |
| **ECS Task Role** | **Kubernetes ServiceAccount + IRSA** | Pod-level IAM permissions |

## Directory Structure

```
infra-eks/
├── modules/
│   ├── eks_cluster/           # EKS control plane module
│   │   ├── main.tf
│   │   ├── iam.tf
│   │   ├── security-groups.tf
│   │   ├── locals.tf
│   │   ├── vars.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   │
│   ├── eks_node_group/        # Managed worker nodes (EC2) module
│   │   ├── main.tf            # Node group with launch template
│   │   ├── iam.tf             # IAM roles and policies
│   │   ├── locals.tf
│   │   ├── vars.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   │   # Note: AWS EKS automatically handles node bootstrapping
│   │   # for managed node groups. No custom user data needed.
│   │
│   └── k8s_app_deployment/    # Kubernetes manifests via Terraform
│       ├── main.tf
│       ├── deployment.tf
│       ├── service.tf
│       ├── ingress.tf
│       ├── vars.tf
│       └── outputs.tf
│
├── deployment/
│   └── prod/
│       ├── vpc/               # Reuses existing VPC module
│       ├── eks_cluster/       # Deploy EKS cluster
│       ├── eks_node_group/    # Deploy worker nodes
│       └── k8s_app/           # Deploy application to Kubernetes
│
├── k8s-manifests/             # Raw Kubernetes YAML manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── hpa.yaml
│
└── README.md                  # This file
```

## Key Differences: ECS vs EKS

### 1. Container Orchestration

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

### 2. Networking

**ECS:**
- ECS tasks use ENIs (awsvpc mode)
- ALB target groups register tasks directly
- Security groups on tasks

**EKS:**
- Pods use AWS VPC CNI for IP addresses
- ALB Ingress Controller creates target groups
- Security groups on nodes + network policies

### 3. Scaling

**ECS:**
- ECS Capacity Provider scales EC2 instances
- ECS Service Auto Scaling scales tasks
- Target tracking based on CPU/memory

**EKS:**
- Cluster Autoscaler scales nodes
- Horizontal Pod Autoscaler (HPA) scales pods
- Metrics Server provides resource metrics

### 4. Service Discovery

**ECS:**
- AWS Cloud Map for service discovery
- ALB for external load balancing
- ECS service connects to target groups

**EKS:**
- Kubernetes DNS (CoreDNS) for service discovery
- AWS Load Balancer Controller for external LB
- Ingress resources create ALBs automatically

### 5. IAM Permissions

**ECS:**
- Task Role: IAM role for application
- Execution Role: IAM role for ECS agent
- Directly attached to task definition

**EKS:**
- ServiceAccount: Kubernetes identity for pods
- IRSA (IAM Roles for Service Accounts): Maps K8s SA to IAM role
- Annotated on ServiceAccount

## Prerequisites

### 1. Kubernetes Tools

```bash
# Install kubectl (Kubernetes CLI)
brew install kubectl

# Install helm (Kubernetes package manager)
brew install helm

# Install aws-iam-authenticator
brew install aws-iam-authenticator
```

### 2. AWS Load Balancer Controller

The EKS cluster requires the AWS Load Balancer Controller to create ALBs from Ingress resources.

**Installation (after EKS cluster is created):**

```bash
# Get cluster name
export CLUSTER_NAME=$(terraform output -raw cluster_id)

# Create IAM policy for Load Balancer Controller
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json

# Install via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=true \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::ACCOUNT_ID:role/AWSLoadBalancerControllerRole
```

### 3. Metrics Server (for HPA)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## Deployment Steps

### Step 1: Deploy VPC (Reuse Existing)

The VPC is shared between ECS and EKS implementations:

```bash
cd ../infra/deployment/app/vpc
terraform init
terraform plan
terraform apply
```

### Step 2: Deploy EKS Cluster

```bash
cd infra-eks/deployment/app/eks_cluster
terraform init
terraform plan
terraform apply
```

**⏱ Time:** ~10-15 minutes (EKS control plane creation)

### Step 3: Configure kubectl

```bash
# Update kubeconfig to connect to EKS cluster
aws eks update-kubeconfig \
  --region eu-west-1 \
  --name $(terraform output -raw cluster_id)

# Verify connection
kubectl get nodes
# Should show: No resources found (nodes not yet created)
```

### Step 4: Deploy EKS Node Group

```bash
cd ../eks_node_group
terraform init
terraform plan
terraform apply
```

**⏱ Time:** ~5-8 minutes (EC2 instances + node registration)

**Verify:**
```bash
kubectl get nodes
# Should show: Ready nodes
```

### Step 5: Install AWS Load Balancer Controller

```bash
# Follow instructions in Prerequisites section
```

### Step 6: Deploy Application

```bash
cd ../k8s_app
terraform init
terraform plan
terraform apply
```

**⏱ Time:** ~3-5 minutes (pods creation + ALB provisioning)

**Verify:**
```bash
kubectl get pods
kubectl get svc
kubectl get ingress

# Get ALB DNS name
kubectl get ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

## Accessing Your Application

### Via ALB (External Access)

```bash
# Get ALB hostname from Ingress
ALB_URL=$(kubectl get ingress app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl http://$ALB_URL
```

### Via Kubectl Port-Forward (Direct Access)

```bash
# Forward local port 8080 to pod port 3000
kubectl port-forward svc/nestjs-app 8080:80

# Access via localhost
curl http://localhost:8080
```

## Kubernetes Manifests Explanation

### 1. Deployment (deployment.yaml)

Equivalent to ECS Task Definition + Service:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nestjs-app
spec:
  replicas: 2  # Like ECS desired count
  template:
    spec:
      containers:
      - name: nestjs
        image: <ECR_IMAGE>
        ports:
        - containerPort: 3000
        resources:
          requests:
            memory: "512Mi"
            cpu: "256m"
          limits:
            memory: "1024Mi"
            cpu: "512m"
```

**Key Concepts:**
- `replicas`: Number of pod copies (like ECS desired count)
- `resources.requests`: Minimum guaranteed resources
- `resources.limits`: Maximum allowed resources
- `livenessProbe`: Health check (like ECS health check)

### 2. Service (service.yaml)

Equivalent to ECS Service (internal load balancing):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nestjs-app
spec:
  type: NodePort  # Exposes on each node's IP
  selector:
    app: nestjs-app
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
```

**Types:**
- `ClusterIP`: Internal only (default)
- `NodePort`: Exposed on node ports (30000-32767)
- `LoadBalancer`: Creates external load balancer

### 3. Ingress (ingress.yaml)

Equivalent to ALB + Target Group + Listener Rules:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nestjs-app
            port:
              number: 80
```

**AWS Load Balancer Controller creates:**
- ALB
- Target Group (pointing to pod IPs)
- Listener Rules (based on paths)

### 4. HorizontalPodAutoscaler (hpa.yaml)

Equivalent to ECS Service Auto Scaling:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nestjs-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nestjs-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## Cost Comparison: ECS vs EKS

### ECS Costs

**For 2 tasks (t3.medium instances):**
- EC2 Instances: ~$60/month (2 × t3.medium)
- ECS Control Plane: **FREE**
- ALB: ~$16/month
- **Total: ~$76/month**

### EKS Costs

**For 2 nodes (t3.medium instances):**
- EC2 Instances: ~$60/month (2 × t3.medium)
- **EKS Control Plane: $72/month** (0.10/hour × 24 × 30)
- ALB: ~$16/month
- **Total: ~$148/month**

**Key Difference:** EKS charges $0.10/hour for the managed Kubernetes control plane (~$72/month), while ECS control plane is free.

### When to Choose EKS Despite Higher Cost

1. **Multi-Cloud Strategy**: Need Kubernetes portability
2. **Kubernetes Expertise**: Team already knows K8s
3. **Advanced Features**: Need K8s-specific features (StatefulSets, DaemonSets, Operators)
4. **Ecosystem**: Leverage Kubernetes ecosystem (Helm charts, operators)
5. **Standardization**: Standardize on K8s across all environments

## Monitoring and Observability

### CloudWatch Container Insights

```bash
# Install CloudWatch agent (FluentBit)
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml
```

### Kubernetes Dashboard (Optional)

```bash
# Install dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Create admin user
kubectl create serviceaccount dashboard-admin-sa
kubectl create clusterrolebinding dashboard-admin-sa \
  --clusterrole=cluster-admin \
  --serviceaccount=default:dashboard-admin-sa

# Get token
kubectl -n default create token dashboard-admin-sa

# Proxy
kubectl proxy

# Access: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods

# Describe pod for events
kubectl describe pod <POD_NAME>

# Check logs
kubectl logs <POD_NAME>

# Check previous container logs (if crashed)
kubectl logs <POD_NAME> --previous
```

### ALB Not Created

```bash
# Check Ingress status
kubectl describe ingress app-ingress

# Check Load Balancer Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Common issues:
# 1. Load Balancer Controller not installed
# 2. IAM permissions missing
# 3. Subnet tags missing (kubernetes.io/role/elb=1)
```

### Nodes Not Joining Cluster

```bash
# Check node group status in AWS Console
# EKS → Clusters → Node Groups

# Check IAM role has required policies:
# - AmazonEKSWorkerNodePolicy
# - AmazonEKS_CNI_Policy
# - AmazonEC2ContainerRegistryReadOnly

# SSH to node (if SSM enabled)
aws ssm start-session --target <INSTANCE_ID>

# Check kubelet logs
sudo journalctl -u kubelet
```

## Cleanup

**⚠️ Important:** Destroy in reverse order to avoid dependency issues

```bash
# Step 1: Delete Kubernetes resources (this deletes ALB)
cd infra-eks/deployment/app/k8s_app
terraform destroy

# Step 2: Delete node group
cd ../eks_node_group
terraform destroy

# Step 3: Delete EKS cluster
cd ../eks_cluster
terraform destroy

# Step 4: (Optional) Delete VPC if not used by ECS
cd ../../../infra/deployment/app/vpc
terraform destroy
```

## Advantages of EKS

✅ **Portability**: Run anywhere (AWS, GCP, Azure, on-prem)
✅ **Ecosystem**: Access to Kubernetes ecosystem (Helm, Operators)
✅ **Standardization**: Industry-standard container orchestration
✅ **Advanced Features**: StatefulSets, DaemonSets, CronJobs, etc.
✅ **Community**: Large open-source community
✅ **Multi-tenancy**: Namespace isolation
✅ **Extensibility**: Custom Resource Definitions (CRDs)

## Disadvantages of EKS

❌ **Cost**: $72/month for control plane (ECS is free)
❌ **Complexity**: Steeper learning curve than ECS
❌ **Overhead**: More moving parts (kubelet, kube-proxy, etc.)
❌ **Maintenance**: Need to manage Kubernetes upgrades
❌ **AWS Integration**: Less tight integration than ECS

## Next Steps

1. **Implement CI/CD**: Update GitHub Actions to deploy to EKS
2. **Add Monitoring**: Set up Prometheus + Grafana
3. **Implement GitOps**: Use ArgoCD or FluxCD
4. **Add Service Mesh**: Istio or Linkerd for advanced traffic management
5. **Implement Network Policies**: Restrict pod-to-pod communication
6. **Add Cert-Manager**: Automate TLS certificate management
7. **Implement Secrets Management**: External Secrets Operator with AWS Secrets Manager

## References

- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)

---

**Created:** 2025-12-03
**Status:** Complete EKS alternative to ECS implementation
**Compatibility:** Runs alongside existing ECS infrastructure
