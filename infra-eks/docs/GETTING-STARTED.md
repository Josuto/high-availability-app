# Getting Started with EKS Infrastructure

Welcome! This guide will help you get started with the EKS (Elastic Kubernetes Service) infrastructure that runs alongside your existing ECS deployment.

## Quick Links

- **New to this project?** Start with [README.md](README.md)
- **Want to deploy quickly?** Follow [QUICKSTART.md](QUICKSTART.md)
- **Comparing ECS vs EKS?** Read [ECS-vs-EKS-COMPARISON.md](ECS-vs-EKS-COMPARISON.md)
- **Need complete details?** See [COMPLETE-IMPLEMENTATION-GUIDE.md](COMPLETE-IMPLEMENTATION-GUIDE.md)
- **Using GitHub Actions?** Check [workflows/README.md](workflows/README.md)
- **Understanding deployment methods?** Read [DEPLOYMENT-APPROACHES.md](DEPLOYMENT-APPROACHES.md)

## What Is This?

This directory (`infra-eks/`) contains a complete AWS EKS infrastructure implementation that:

✅ **Runs alongside your existing ECS setup** - No conflicts, both can run simultaneously
✅ **Shares common resources** - Uses same VPC, ECR, and SSL certificates
✅ **Provides two deployment options** - YAML manifests OR Terraform
✅ **Includes CI/CD workflows** - GitHub Actions for automated deployment
✅ **Production-ready** - Security best practices, auto-scaling, monitoring

## Architecture at a Glance

```
Your AWS Account
├── Shared Resources (used by both ECS and EKS)
│   ├── VPC with public & private subnets
│   ├── ECR (Docker container registry)
│   └── ACM Certificate (SSL/TLS)
│
├── ECS Infrastructure (infra/)
│   ├── ECS Cluster
│   ├── ECS Service
│   └── Application Load Balancer
│
└── EKS Infrastructure (infra-eks/) ← This directory
    ├── EKS Cluster (Kubernetes control plane)
    ├── EKS Node Group (worker nodes)
    ├── AWS Load Balancer Controller
    └── Kubernetes Application
        ├── Deployment (pods)
        ├── Service (internal LB)
        ├── Ingress (creates ALB)
        └── HPA (auto-scaling)
```

## What's Included?

### 1. Terraform Modules

**Location:** `modules/`

Three reusable modules:
- `eks_cluster/` - EKS control plane with security and logging
- `eks_node_group/` - Managed worker nodes with auto-scaling
- `k8s_app/` - Kubernetes application deployment

### 2. Production Deployments

**Location:** `deployment/app/`

Ready-to-use configurations:
- `eks_cluster/` - Deploy EKS cluster
- `eks_node_group/` - Deploy worker nodes
- `k8s_app/` - Deploy application

### 3. Kubernetes Manifests

**Location:** `k8s-manifests/`

Raw YAML files for kubectl deployment:
- `deployment.yaml` - Application pods
- `service.yaml` - Internal service
- `ingress.yaml` - ALB configuration
- `hpa.yaml` - Auto-scaling rules

### 4. Helper Scripts

**Location:** `scripts/`

- `generate-manifests.sh` - Replace placeholders with actual values from Terraform state

### 5. GitHub Actions Workflows

**Location:** `workflows/`

- `deploy_eks_infra.yaml` - Automated deployment workflow
- `destroy_eks_infra.yaml` - Safe destruction workflow
- `README.md` - Detailed workflow documentation

### 6. Documentation

**You are here!**

- `GETTING-STARTED.md` (this file) - Start here
- `README.md` - Complete infrastructure guide
- `QUICKSTART.md` - 30-minute deployment
- `ECS-vs-EKS-COMPARISON.md` - Feature comparison
- `DEPLOYMENT-APPROACHES.md` - YAML vs Terraform
- `COMPLETE-IMPLEMENTATION-GUIDE.md` - Everything you need to know
- `deployment/app/SHARED-RESOURCES.md` - Resource sharing guide

## Choose Your Path

### Path 1: I Want to Deploy EKS Manually

**Best for:** Learning, testing, or when you want full control

1. Read [QUICKSTART.md](QUICKSTART.md) for step-by-step instructions
2. Ensure shared resources are deployed (VPC, ECR, SSL)
3. Deploy EKS cluster → nodes → application
4. Takes ~30-40 minutes

### Path 2: I Want Automated CI/CD

**Best for:** Production use, team collaboration

1. Read [workflows/README.md](workflows/README.md)
2. Copy workflows to `.github/workflows/`
3. Configure GitHub Secrets
4. Push to main branch - workflow runs automatically

### Path 3: I Want to Compare ECS vs EKS

**Best for:** Decision-making, understanding differences

1. Read [ECS-vs-EKS-COMPARISON.md](ECS-vs-EKS-COMPARISON.md)
2. Compare costs, features, and complexity
3. Decide which platform fits your needs

### Path 4: I Want to Understand Everything

**Best for:** Architects, senior engineers

1. Read [COMPLETE-IMPLEMENTATION-GUIDE.md](COMPLETE-IMPLEMENTATION-GUIDE.md)
2. Review module source code
3. Understand architecture decisions

## Prerequisites

Before you start, ensure you have:

### Required Tools
- [x] Terraform >= 1.7.0
- [x] kubectl >= 1.32.0
- [x] AWS CLI configured
- [x] Helm >= 3.13.0 (for Load Balancer Controller)

### AWS Resources
- [x] VPC deployed (`infra/deployment/app/vpc/`)
- [x] ECR deployed (`infra/deployment/ecr/`)
- [x] SSL certificate (`infra/deployment/ssl/`)
- [x] Terraform state S3 bucket

### Permissions
- [x] AWS credentials with EKS permissions
- [x] IAM permissions for creating roles
- [x] Network admin for security groups

## Quick Start (5 Minutes)

Want to see if everything is set up correctly?

```bash
# 1. Check prerequisites
terraform version    # Should be >= 1.7.0
kubectl version --client
aws --version
helm version

# 2. Verify shared resources exist
cd infra/deployment/app/vpc && terraform output vpc_id
cd ../../ecr && terraform output ecr_repository_url
cd ../ssl && terraform output acm_certificate_validation_arn

# 3. Review EKS configuration
cd infra-eks/deployment/app/eks_cluster
cat vars.tf  # Check default values

# 4. Initialize Terraform (dry run)
terraform init
terraform plan -var="state_bucket_name=YOUR_BUCKET"

# If plan succeeds, you're ready to deploy!
```

## Cost Estimate

Running this EKS infrastructure will cost approximately:

| Component | Monthly Cost |
|-----------|--------------|
| EKS Control Plane | $72 |
| 2 × t3.medium nodes | $60 |
| Application Load Balancer | $16 |
| CloudWatch Logs | $5 |
| **Total** | **~$153/month** |

**Note:** This is in addition to ECS costs if running both platforms.

**Cost Savings:**
- Use SPOT instances for dev: Save ~70% on nodes
- Share control plane: Run multiple apps to amortize cost
- Scale down when not in use: Reduce node costs

## What's Different from ECS?

| Aspect | ECS | EKS |
|--------|-----|-----|
| **Control Plane Cost** | FREE | $72/month |
| **Total Cost** | ~$76/month | ~$148/month |
| **Complexity** | Simpler | More complex |
| **Portability** | AWS-only | Multi-cloud |
| **Ecosystem** | AWS services | Kubernetes ecosystem |
| **Learning Curve** | Easier | Steeper |
| **Deployment Time** | 15-20 min | 30-40 min |

**When to use EKS:**
- Need Kubernetes-standard platform
- Want to avoid vendor lock-in
- Have Kubernetes expertise
- Running multiple microservices (3+)
- Need advanced features (StatefulSets, Operators, etc.)

**When to use ECS:**
- Want simplicity and lower cost
- AWS-centric architecture
- Small team or few services
- Quick time to market

## Common Questions

**Q: Can I run both ECS and EKS at the same time?**

A: Yes! They share VPC, ECR, and SSL but have separate compute resources. This is ideal for gradual migration or A/B testing.

**Q: Will this affect my existing ECS deployment?**

A: No. EKS resources use separate Terraform state (`deployment/`) and don't modify ECS infrastructure.

**Q: How do I migrate from ECS to EKS?**

A:
1. Deploy EKS alongside ECS
2. Test EKS deployment
3. Switch DNS to EKS ALB
4. Decommission ECS

See [ECS-vs-EKS-COMPARISON.md](ECS-vs-EKS-COMPARISON.md) for detailed migration guide.

**Q: Do I need to deploy VPC, ECR, and SSL again?**

A: No! These are shared resources already deployed in `infra/`. EKS references them via remote state.

**Q: Which deployment approach should I use: YAML or Terraform?**

A: **YAML** is recommended for most teams (industry standard, GitOps-friendly). Use **Terraform** if you want unified tooling. See [DEPLOYMENT-APPROACHES.md](DEPLOYMENT-APPROACHES.md).

**Q: Can I use this in production?**

A: Yes! This implementation follows AWS best practices:
- Security groups properly configured
- IMDSv2 required on nodes
- Control plane logging enabled
- Auto-scaling configured
- Cost allocation tags applied

## Next Steps

1. **Choose your deployment path** (see "Choose Your Path" above)
2. **Read the relevant guide** (QUICKSTART.md or workflows/README.md)
3. **Deploy EKS infrastructure**
4. **Test your application**
5. **Set up monitoring** (CloudWatch, Prometheus, Grafana)
6. **Configure CI/CD** (GitHub Actions workflows)

## Getting Help

If you encounter issues:

1. **Check the documentation:**
   - [Troubleshooting section in COMPLETE-IMPLEMENTATION-GUIDE.md](COMPLETE-IMPLEMENTATION-GUIDE.md#troubleshooting)
   - [workflows/README.md troubleshooting](workflows/README.md#troubleshooting)

2. **Review logs:**
   ```bash
   # EKS cluster logs
   aws eks describe-cluster --name CLUSTER_NAME

   # Node logs
   kubectl get nodes
   kubectl describe node NODE_NAME

   # Application logs
   kubectl logs -f deployment/nestjs-app-deployment

   # Load Balancer Controller logs
   kubectl logs -n kube-system deployment/aws-load-balancer-controller
   ```

3. **Check AWS Console:**
   - EKS service
   - EC2 instances
   - Load Balancers
   - CloudWatch logs

4. **Debug with kubectl:**
   ```bash
   kubectl get all
   kubectl describe pod POD_NAME
   kubectl get events --sort-by='.lastTimestamp'
   ```

## Contributing

Found an issue or want to improve this infrastructure?

1. Open an issue in the repository
2. Submit a pull request
3. Update documentation

## Summary

You now have:
- ✅ Complete EKS infrastructure code
- ✅ Multiple deployment options (manual, CI/CD, YAML, Terraform)
- ✅ Comprehensive documentation
- ✅ Production-ready configuration
- ✅ Cost optimization strategies
- ✅ Troubleshooting guides

**Ready to start?** Pick your path above and begin deploying!

---

**Happy Deploying! 🚀**

*Last Updated: 2025-12-06*
