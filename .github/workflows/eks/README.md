# EKS GitHub Actions Workflows

This directory contains GitHub Actions workflows for deploying and managing the EKS infrastructure.

## ⚠️ Important: Workflow Location

These workflow files are provided in `.github/workflows/eks/` for reference and documentation purposes.

**✅ These workflows have already been copied to `.github/workflows/` with EKS-specific naming:**

| Source (.github/workflows/eks/) | Destination (.github/workflows/) |
|-------------------------------|----------------------------------|
| deploy_terraform_state_bucket.yaml | deploy_terraform_state_bucket_eks.yaml |
| deploy_hosted_zone.yaml | deploy_hosted_zone_eks.yaml |
| destroy_hosted_zone.yaml | destroy_hosted_zone_eks.yaml |
| deploy_shared_aws_infra.yaml | deploy_shared_aws_infra_eks.yaml |
| destroy_shared_aws_infra.yaml | destroy_shared_aws_infra_eks.yaml |
| deploy_eks_infra.yaml | deploy_eks_infra.yaml |
| destroy_eks_infra.yaml | destroy_eks_infra.yaml |

The EKS workflows use the `_eks` suffix (or are named specifically for EKS) to avoid conflicts with the existing ECS workflows. Both ECS and EKS workflows can coexist in `.github/workflows/` without interference.

## Why Are They Here?

The workflows are placed in `.github/workflows/eks/` (instead of `.github/workflows/`) because:

1. **Documentation** - Keep EKS-related workflows with EKS infrastructure code
2. **Separation** - Avoid automatically triggering EKS workflows when you only want ECS
3. **Optional** - Allow users to choose whether to enable EKS CI/CD
4. **Reference** - Provide templates that can be customized before activation

## Available Workflows

### 1. deploy_terraform_state_bucket.yaml

**Purpose:** Create S3 bucket for Terraform state storage (reusable workflow)

**Triggers:**
- Called by other workflows (workflow_call)
- Not directly triggered

**What It Does:**
1. Checks if S3 bucket exists
2. Creates bucket if it doesn't exist
3. Configures bucket for state storage

**Prerequisites:**
- AWS credentials configured
- Unique bucket name in `backend.tfvars`

**Execution Time:** ~2 minutes

### 2. deploy_hosted_zone.yaml

**Purpose:** Deploy Route53 hosted zone and state bucket

**Triggers:**
- Manual workflow dispatch only

**What It Does:**
1. Deploys Terraform state bucket (via reusable workflow)
2. Creates Route53 hosted zone for DNS management
3. Required for SSL certificate validation

**Prerequisites:**
- Domain name configured in `domain.tfvars`
- AWS credentials configured

**Execution Time:** ~3-5 minutes

### 3. destroy_hosted_zone.yaml

**Purpose:** Destroy Route53 hosted zone and state bucket

**Triggers:**
- Manual workflow dispatch only

**What It Does:**
1. Destroys Route53 hosted zone
2. Deletes all state files from S3 bucket
3. Destroys the S3 state bucket itself

**⚠️ Warning:** This will delete ALL Terraform state files. Only use when completely tearing down infrastructure.

**Execution Time:** ~5 minutes

### 4. deploy_shared_aws_infra.yaml

**Purpose:** Deploy shared AWS infrastructure (VPC, ECR, SSL, Docker image)

**Triggers:**
- Manual workflow dispatch only

**What It Does:**
1. Tests Terraform modules
2. Deploys Terraform state bucket (via reusable workflow)
3. Creates ECR container registry
4. Retrieves/creates SSL certificate
5. Builds and pushes Docker image to ECR
6. Deploys VPC with EKS-specific subnet tags

**Prerequisites:**
- Domain name configured in `domain.tfvars`
- AWS credentials configured
- Terraform state bucket name in `backend.tfvars`

**Execution Time:** ~15-20 minutes

**Workflow Jobs:**
```
test-terraform-modules (2 min)
  ↓
deploy-terraform-state-bucket (2 min)
  ↓
├─ deploy-ecr (3 min)
│    ↓
│  build-and-push-app-docker-image-to-ecr (5 min)
│    ↓
│  deploy-vpc (5 min)
└─ retrieve-ssl (3 min)
  ↓
deployment-summary (30 sec)
```

### 5. destroy_shared_aws_infra.yaml

**Purpose:** Destroy shared AWS infrastructure (VPC, ECR, SSL)

**Triggers:**
- Manual workflow dispatch only (for safety)
- Requires typing "destroy-shared" as confirmation

**What It Does:**
1. Validates destruction confirmation
2. Destroys SSL certificate
3. Deletes ECR images and destroys repository
4. Destroys VPC
5. Preserves Terraform state bucket and hosted zone

**Prerequisites:**
- Shared infrastructure is deployed
- GitHub Secrets configured

**Execution Time:** ~10-15 minutes

**⚠️ Important Safety Features:**
- Manual trigger only (no automatic destruction)
- Requires explicit "destroy-shared" confirmation
- Deletes all ECR images before destroying repository
- Preserves state bucket and hosted zone for safety

**Workflow Jobs:**
```
validate-destruction (30 sec)
  ↓
├─ destroy-ssl (3 min)
└─ destroy-ecr (5 min)
  ↓
destroy-vpc (5 min)
  ↓
destruction-summary (30 sec)
```

### 6. deploy_eks_infra.yaml

**Purpose:** Automated deployment of the complete EKS infrastructure

**Triggers:**
- Push to `main` branch with changes in `infra-eks/**`
- Manual workflow dispatch

**What It Does:**
1. Tests EKS Terraform modules
2. Verifies shared resources (VPC, ECR, SSL) exist
3. Deploys EKS cluster
4. Deploys EKS node group
5. Installs AWS Load Balancer Controller
6. Deploys Kubernetes application (Deployment, Service, Ingress, HPA)
7. Outputs application URL

**Prerequisites:**
- Shared resources deployed (VPC, ECR, SSL via `deploy_shared_aws_infra.yaml`)
- GitHub Secrets configured (see below)
- Terraform state bucket exists

**Execution Time:** ~30-40 minutes

**Workflow Jobs:**
```
test-eks-terraform-modules (2 min)
  ↓
verify-shared-resources (1 min)
  ↓
deploy-eks-cluster (15 min)
  ↓
deploy-eks-node-group (10 min)
  ↓
install-aws-load-balancer-controller (5 min)
  ↓
deploy-k8s-application (5 min)
  ↓
deployment-summary (1 min)
```

### 7. destroy_eks_infra.yaml

**Purpose:** Safe teardown of EKS infrastructure

**Triggers:**
- Manual workflow dispatch only (for safety)
- Requires typing "destroy" as confirmation

**What It Does:**
1. Validates destruction confirmation
2. Destroys Kubernetes application resources
3. Uninstalls AWS Load Balancer Controller
4. Destroys EKS node group
5. Destroys EKS cluster
6. Cleans up orphaned resources (ALBs, security groups, ENIs)
7. Preserves shared resources (VPC, ECR, ACM)

**Prerequisites:**
- EKS infrastructure is deployed
- GitHub Secrets configured

**Execution Time:** ~20-30 minutes

**Important Safety Features:**
- Manual trigger only (no automatic destruction)
- Requires explicit "destroy" confirmation
- Cleans up ALBs before destroying cluster (prevents orphaned resources)
- Reports orphaned resources that need manual cleanup
- Preserves shared resources used by ECS

**Workflow Jobs:**
```
validate-destruction (30 sec)
  ↓
destroy-k8s-application (5 min)
  ↓
uninstall-aws-load-balancer-controller (3 min)
  ↓
destroy-eks-node-group (10 min)
  ↓
destroy-eks-cluster (15 min)
  ↓
cleanup-orphaned-resources (2 min)
  ↓
destruction-summary (30 sec)
```

## Required GitHub Secrets

Configure these secrets in your GitHub repository:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key ID | `AKIAIOSFODNN7EXAMPLE` # pragma: allowlist secret |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` # pragma: allowlist secret |
| `TERRAFORM_STATE_BUCKET_NAME` | S3 bucket for Terraform state | `my-terraform-state-bucket` |

**How to Add Secrets:**
1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret listed above

## Configuration Files Required

These workflows assume the following configuration files exist in your repository:

### infra-eks/common.tfvars
```hcl
project_name = "terraform-course-dummy-nestjs-app"
environment  = "prod"
```

### infra-eks/backend-config.hcl
```hcl
bucket = "YOUR_TERRAFORM_STATE_BUCKET_NAME"
key    = "deployment-eks/terraform.tfstate"
region = "eu-west-1"
```

## Usage

### Complete Deployment Order

The recommended order for deploying the complete EKS infrastructure:

1. **Deploy Hosted Zone and State Bucket** (one-time setup)
   - Run: `Deploy AWS Route53 Hosted Zone and Terraform State Bucket (EKS)` workflow
   - Creates: Route53 hosted zone, S3 state bucket

2. **Deploy Shared Infrastructure** (VPC, ECR, SSL)
   - Run: `Deploy Shared AWS Infrastructure for EKS` workflow
   - Creates: VPC, ECR repository, SSL certificate, Docker image

3. **Deploy EKS Cluster and Application**
   - Run: `Deploy EKS Infrastructure` workflow (can be automatic or manual)
   - Creates: EKS cluster, node group, Load Balancer Controller, K8s application

### Deploying Shared Infrastructure

**Step 1: Deploy Hosted Zone and State Bucket** (one-time setup)

1. Go to GitHub Actions tab
2. Select "Deploy AWS Route53 Hosted Zone and Terraform State Bucket (EKS)" workflow
3. Click "Run workflow"
4. Select branch (usually `main`)
5. Click "Run workflow"
6. Wait ~3-5 minutes

**Step 2: Deploy Shared Resources** (VPC, ECR, SSL)

1. Go to GitHub Actions tab
2. Select "Deploy Shared AWS Infrastructure for EKS" workflow
3. Click "Run workflow"
4. Select branch (usually `main`)
5. Click "Run workflow"
6. Wait ~15-20 minutes

### Deploying EKS Infrastructure

**Option 1: Automatic Trigger (Recommended)**

```bash
# 1. Copy workflows to .github/workflows/
cp .github/workflows/eks/*.yaml .github/workflows/

# 2. Make changes to EKS infrastructure
git add infra-eks/
git commit -m "feat: update EKS configuration"
git push origin main

# 3. Workflow triggers automatically
# Monitor at: https://github.com/YOUR_ORG/YOUR_REPO/actions
```

**Option 2: Manual Trigger**

1. Go to GitHub Actions tab
2. Select "Deploy EKS Infrastructure" workflow
3. Click "Run workflow"
4. Select branch (usually `main`)
5. Click "Run workflow"

### Destroying EKS Infrastructure

**⚠️ Warning:** This will destroy all EKS resources but preserve shared VPC, ECR, and ACM.

```bash
# 1. Go to GitHub Actions tab
# 2. Select "Destroy EKS Infrastructure" workflow
# 3. Click "Run workflow"
# 4. Type "destroy" in the confirmation field
# 5. Click "Run workflow"
```

### Destroying Shared Infrastructure

**⚠️ Warning:** This will destroy VPC, ECR, and SSL. Only run after destroying EKS infrastructure.

```bash
# 1. Go to GitHub Actions tab
# 2. Select "Destroy Shared AWS Infrastructure for EKS" workflow
# 3. Click "Run workflow"
# 4. Type "destroy-shared" in the confirmation field
# 5. Click "Run workflow"
```

### Destroying Hosted Zone and State Bucket

**⚠️ Warning:** This will delete ALL Terraform state files and the hosted zone. Only run when completely tearing down infrastructure.

```bash
# 1. Go to GitHub Actions tab
# 2. Select "Destroy Route53 Hosted Zone and Terraform State Bucket (EKS)" workflow
# 3. Click "Run workflow"
# 4. Wait ~5 minutes
```

**Complete Destruction Order:**
1. Destroy EKS Infrastructure (`destroy_eks_infra.yaml`)
2. Destroy Shared Infrastructure (`destroy_shared_aws_infra.yaml`)
3. Destroy Hosted Zone and State Bucket (`destroy_hosted_zone.yaml`)

## Workflow Customization

### Change Kubernetes Version

Edit `.github/workflows/eks/deploy_eks_infra.yaml`:

```yaml
env:
  KUBECTL_VERSION: 1.28.0  # Change to desired version
```

Also update `infra-eks/modules/eks_cluster/vars.tf`:

```hcl
variable "kubernetes_version" {
  default = "1.28"  # Match major.minor version
}
```

### Change AWS Region

Edit workflow files:

```yaml
env:
  AWS_REGION: eu-west-1  # Change to your region
```

Also update all backend configurations and tfvars files.

### Change Terraform Version

Edit workflow files:

```yaml
env:
  TERRAFORM_VERSION: 1.10.3  # Change to desired version
```

### Disable Automatic Deployment

Remove the `push` trigger from `deploy_eks_infra.yaml`:

```yaml
on:
  # Remove these lines to disable automatic deployment
  # push:
  #   branches:
  #     - main
  #   paths:
  #     - 'infra-eks/**'

  workflow_dispatch:  # Keep manual trigger
```

### Add Slack Notifications

Add a notification step at the end of workflows:

```yaml
- name: Notify Slack
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "EKS deployment completed: ${{ job.status }}"
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## Troubleshooting

### Workflow Fails at "verify-shared-resources"

**Problem:** VPC, ECR, or SSL not deployed

**Solution:**
```bash
# Deploy shared resources first
cd infra/deployment/prod/vpc && terraform apply
cd ../../ecr && terraform apply
cd ../ssl && terraform apply
```

### Workflow Fails at "install-aws-load-balancer-controller"

**Problem:** IAM OIDC provider or IAM policy issues

**Solution:**
1. Check that EKS cluster was created successfully
2. Verify IAM permissions for your AWS credentials
3. Manually create OIDC provider:
   ```bash
   eksctl utils associate-iam-oidc-provider \
     --cluster prod-terraform-course-dummy-nestjs-app-eks-cluster \
     --region eu-west-1 \
     --approve
   ```

### Workflow Fails at "deploy-k8s-application"

**Problem:** Load Balancer Controller not ready or Ingress issues

**Solution:**
1. Verify Load Balancer Controller is running:
   ```bash
   kubectl get deployment -n kube-system aws-load-balancer-controller
   ```
2. Check controller logs:
   ```bash
   kubectl logs -n kube-system deployment/aws-load-balancer-controller
   ```
3. Verify ACM certificate ARN is correct in Terraform state

### Destroy Workflow Leaves Orphaned ALBs

**Problem:** ALBs not cleaned up before cluster deletion

**Solution:**
1. Manually delete ALBs via AWS Console
2. Wait 5 minutes for deletion to complete
3. Re-run destroy workflow

### Workflow Takes Too Long

**Problem:** EKS cluster creation is slow (15-20 minutes is normal)

**Solution:** This is expected behavior. EKS cluster creation inherently takes time. Consider:
- Using Terraform workspaces for faster updates (skip cluster recreation)
- Using EKS Fargate for faster scaling (but higher cost)
- Pre-creating clusters and only deploying applications

## Differences from ECS Workflows

| Aspect | ECS Workflow | EKS Workflow |
|--------|--------------|--------------|
| **Deployment Time** | ~15-20 min | ~30-40 min |
| **Complexity** | Simpler | More complex |
| **Additional Steps** | None | Install Load Balancer Controller |
| **Application Deployment** | ECS Service | Kubernetes manifests |
| **Load Balancer** | Created by Terraform | Created by Ingress |
| **Destroy Safety** | Standard | Enhanced (manual confirmation) |
| **Shared Resources** | VPC, ECR, ACM | VPC, ECR, ACM |
| **Cost** | $76/month | $148/month |

## Integration with Existing ECS Workflows

These EKS workflows are designed to run alongside existing ECS workflows without conflicts:

1. **Shared Resources:** Both use the same VPC, ECR, and ACM
2. **Separate State:** EKS uses `deployment-eks/` state path
3. **Independent Triggers:** EKS workflows only trigger on `infra-eks/**` changes
4. **No Conflicts:** Both can run simultaneously

**Example Workflow Triggers:**

```yaml
# ECS Workflow (.github/workflows/deploy_aws_infra.yaml)
on:
  push:
    branches: [main]
    paths: ['infra/**']  # Only triggers on infra/ changes

# EKS Workflow (.github/workflows/deploy_eks_infra.yaml)
on:
  push:
    branches: [main]
    paths: ['infra-eks/**']  # Only triggers on infra-eks/ changes
```

## Cost Considerations

Running these workflows incurs costs:

### GitHub Actions Minutes
- **Free tier:** 2,000 minutes/month for public repos
- **Private repos:** 2,000 minutes/month (varies by plan)
- **Estimated usage:**
  - Deploy workflow: ~40 minutes
  - Destroy workflow: ~30 minutes
  - Monthly (if triggered daily): ~2,100 minutes

**Recommendation:** Use manual triggers for private repos to conserve minutes.

### AWS Infrastructure Costs
- **EKS Control Plane:** $72/month (always charged when cluster exists)
- **EC2 Nodes:** ~$60/month (2 × t3.medium)
- **ALB:** ~$16/month
- **Total:** ~$148/month

**Recommendation:** Use `destroy_eks_infra.yaml` when not actively using EKS.

## Best Practices

1. **Use Manual Triggers for Destruction**
   - Never automate destruction workflows
   - Always require confirmation input

2. **Monitor Workflow Runs**
   - Check GitHub Actions tab regularly
   - Set up notifications for failed workflows

3. **Test in Non-Production First**
   - Use separate AWS accounts for testing
   - Test workflows in a dev environment before prod

4. **Clean Up Regularly**
   - Destroy EKS when not in use to save costs
   - Check for orphaned resources weekly

5. **Version Control Workflow Files**
   - Commit workflow changes to version control
   - Use pull requests for workflow modifications

6. **Secure Secrets**
   - Rotate AWS credentials regularly
   - Use IAM roles with minimal required permissions
   - Never commit secrets to version control

7. **Document Custom Changes**
   - Comment any customizations in workflow files
   - Keep this README updated with your changes

## Security Considerations

### IAM Permissions Required

The AWS credentials used in workflows need these permissions:

**EKS:**
- `eks:*`
- `ec2:*` (for VPC, security groups, ENIs)
- `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:CreateOpenIDConnectProvider`
- `elasticloadbalancing:*` (for ALB creation via Ingress)

**Terraform State:**
- `s3:GetObject`, `s3:PutObject` (for state bucket)
- `dynamodb:*` (if using state locking)

**Least Privilege Example:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:*",
        "ec2:*",
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:CreateOpenIDConnectProvider",
        "elasticloadbalancing:*",
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "*"
    }
  ]
}
```

### Preventing Accidental Deletion

1. **Use Branch Protection**
   - Require pull request reviews
   - Prevent direct pushes to `main`

2. **Add Manual Approval Steps**
   - Use GitHub Environments with required reviewers
   - Example:
     ```yaml
     jobs:
       deploy-eks-cluster:
         environment:
           name: production
           required-reviewers: [your-github-username]
     ```

3. **Add Terraform Backend Locking**
   - Prevents concurrent modifications
   - Uses DynamoDB table for state locking

## FAQ

**Q: Can I run both ECS and EKS simultaneously?**

A: Yes! Both workflows are designed to run alongside each other. They share VPC, ECR, and ACM but have separate compute resources.

**Q: What happens if I push changes to both `infra/` and `infra-eks/`?**

A: Both workflows will trigger independently and run in parallel. This is safe because they use separate Terraform state files.

**Q: How do I roll back a failed deployment?**

A:
1. Revert your commit: `git revert HEAD && git push`
2. Or manually run previous Terraform version:
   ```bash
   cd infra-eks/deployment-eks/prod/eks_cluster
   terraform apply -var-file="../../../common.tfvars"
   ```

**Q: Can I use these workflows with GitHub Enterprise?**

A: Yes, these workflows are compatible with GitHub Enterprise. Adjust runner labels if using self-hosted runners.

**Q: How do I test workflow changes without deploying?**

A: Use the `act` tool to run workflows locally:
```bash
brew install act
act -j test-eks-terraform-modules
```

**Q: What if I want to deploy to multiple environments (dev/staging/prod)?**

A: Create separate workflow files for each environment with different trigger paths:
```yaml
# .github/workflows/deploy_eks_dev.yaml
on:
  push:
    branches: [develop]
    paths: ['infra-eks/**']
```

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Terraform GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)

## Support

For issues with these workflows:
1. Check the [Troubleshooting](#troubleshooting) section above
2. Review GitHub Actions logs in the Actions tab
3. Check Terraform state for inconsistencies
4. Open an issue in the repository

---

**Last Updated:** 2025-12-06
