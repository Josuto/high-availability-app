# EKS Quick Start Guide

Get your application running on Kubernetes (EKS) in under 30 minutes!

## Prerequisites Checklist

- [ ] AWS CLI configured (`aws configure`)
- [ ] Terraform installed (>= 1.7.0)
- [ ] kubectl installed (`brew install kubectl`)
- [ ] helm installed (`brew install helm`)
- [ ] Existing VPC from ECS deployment

## 5-Minute Setup

### Step 1: Deploy EKS Cluster (10 min)

```bash
cd infra-eks/deployment/prod/eks_cluster

# Create terraform.tfvars
cat > terraform.tfvars << EOF
project_name = "terraform-course-dummy-nestjs-app"
environment  = "prod"
EOF

# Deploy
terraform init
terraform plan
terraform apply -auto-approve
```

**☕ Coffee break - this takes ~10 minutes**

### Step 2: Configure kubectl (1 min)

```bash
# Get cluster name
CLUSTER_NAME=$(terraform output -raw cluster_id)

# Update kubeconfig
aws eks update-kubeconfig --region eu-west-1 --name $CLUSTER_NAME

# Verify (should say "No resources found")
kubectl get nodes
```

### Step 3: Deploy Worker Nodes (7 min)

```bash
cd ../eks_node_group

# Create terraform.tfvars
cat > terraform.tfvars << EOF
project_name = "terraform-course-dummy-nestjs-app"
environment  = "prod"
EOF

# Deploy
terraform init
terraform apply -auto-approve
```

**⏱ Wait ~7 minutes for nodes to be ready**

```bash
# Verify nodes are Ready
kubectl get nodes

# Expected output:
# NAME                         STATUS   ROLES    AGE   VERSION
# ip-10-0-1-123...             Ready    <none>   5m    v1.28.x
# ip-10-0-2-456...             Ready    <none>   5m    v1.28.x
```

### Step 4: Install AWS Load Balancer Controller (5 min)

```bash
# Create IAM policy
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json

# Get your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Install via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set region=eu-west-1

# Wait for it to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=aws-load-balancer-controller \
  -n kube-system \
  --timeout=90s
```

### Step 5: Deploy Your Application (3 min)

```bash
cd ../../k8s-manifests

# Update ECR image URL in deployment.yaml
ECR_REPO=$(aws ecr describe-repositories --repository-names YOUR_APP_NAME --query 'repositories[0].repositoryUri' --output text)

sed -i '' "s|<ECR_REPOSITORY_URL>|$ECR_REPO|g" deployment.yaml

# Get ACM certificate ARN
CERT_ARN=$(aws acm list-certificates --query 'CertificateSummaryList[0].CertificateArn' --output text)

sed -i '' "s|<ACM_CERTIFICATE_ARN>|$CERT_ARN|g" ingress.yaml

# Deploy application
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
kubectl apply -f hpa.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=nestjs-app --timeout=120s

# Get ALB URL
ALB_URL=$(kubectl get ingress nestjs-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Your app is available at: http://$ALB_URL"
```

### Step 6: Test Your Application

```bash
# Wait 2-3 minutes for ALB to be fully provisioned
sleep 180

# Test the endpoint
curl http://$ALB_URL

# Should return your app response!
```

## Verification Commands

```bash
# Check all resources
kubectl get all

# Check Ingress and ALB status
kubectl get ingress
kubectl describe ingress nestjs-app-ingress

# Check pod logs
kubectl logs -l app=nestjs-app --tail=50

# Check HPA status
kubectl get hpa

# Check node resource usage
kubectl top nodes
kubectl top pods
```

## Common Issues & Fixes

### Issue: Nodes not joining cluster

```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name $(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --query 'nodegroups[0]' --output text)

# Check if IAM role has required policies
aws iam list-attached-role-policies --role-name ${CLUSTER_NAME}-node-role
```

### Issue: ALB not created

```bash
# Check Load Balancer Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check Ingress events
kubectl describe ingress nestjs-app-ingress

# Verify subnets have required tags
aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/role/elb,Values=1"
```

### Issue: Pods not starting

```bash
# Check pod status
kubectl describe pod -l app=nestjs-app

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check if ECR image is accessible
aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_REPO
```

## Next Steps

### 1. Add Domain Name

Update Route53 to point to ALB:

```bash
# Get hosted zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query 'HostedZones[0].Id' --output text)

# Get ALB hosted zone
ALB_ZONE_ID=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(DNSName, '$ALB_URL')].CanonicalHostedZoneId" \
  --output text)

# Create DNS record
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch file://dns-change.json
```

### 2. Enable HTTPS

Already configured in `ingress.yaml`! Just ensure ACM certificate ARN is correct.

### 3. Set up Monitoring

```bash
# Install Prometheus + Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open: http://localhost:3000 (admin/prom-operator)
```

### 4. Implement GitOps

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Cleanup

```bash
# Delete application
kubectl delete -f k8s-manifests/

# Wait for ALB to be deleted (2-3 minutes)
kubectl get ingress --watch

# Delete node group
cd deployment/prod/eks_node_group
terraform destroy -auto-approve

# Delete cluster
cd ../eks_cluster
terraform destroy -auto-approve
```

## Costs

Running this setup (2 nodes, t3.medium):
- **EKS Control Plane:** $72/month
- **EC2 Instances:** $60/month (2 × t3.medium)
- **ALB:** $16/month
- **CloudWatch:** $5/month
- **Total:** ~$153/month

To reduce costs:
- Use Spot instances in dev (set `capacity_type = "SPOT"`)
- Scale down during off-hours
- Use smaller instance types (t3.small)

## Getting Help

- **EKS User Guide:** https://docs.aws.amazon.com/eks/latest/userguide/
- **Kubernetes Docs:** https://kubernetes.io/docs/
- **AWS Load Balancer Controller:** https://kubernetes-sigs.github.io/aws-load-balancer-controller/

---

**Total Time:** ~26 minutes
**Difficulty:** Intermediate
**Prerequisites:** Basic Kubernetes knowledge

Happy Kubernetes orchestration! 🚀
