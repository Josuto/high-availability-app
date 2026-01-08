# Prerequisites and First-Time Setup

Before deploying this infrastructure, you need to configure several variables and files with your own values. This section guides you through all required configuration changes.

## 1. Prerequisites

Ensure you have the following before starting:

- **AWS Account** with appropriate IAM permissions to create VPC, EKS, ALB, Route53, ACM, ECR, and IAM resources
- **Domain Name** registered at any domain registrar (e.g., GoDaddy, Namecheap, Route53)
- **Terraform 1.0+** installed locally ([Installation Guide](https://developer.hashicorp.com/terraform/downloads))
- **AWS CLI** installed and configured ([Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **kubectl** installed for Kubernetes cluster management ([Installation Guide](https://kubernetes.io/docs/tasks/tools/))
- **(Optional) Helm CLI** for package management ([Installation Guide](https://helm.sh/docs/intro/install/))
- **(Optional) GitHub Repository** if you plan to use the included CI/CD workflows
- **(Optional) Pre-commit Tools** for local development: TFLint, tfsec, detect-secrets, terraform-docs

## 2. Required Configuration Changes

You must update the following configuration files before deployment. All files are located in `infra-eks/deployment/`.

### Step 1: Configure S3 Backend for Terraform State

Update **both files** with your unique S3 bucket name:

**File 1:** `infra-eks/deployment/backend.tfvars`
```hcl
# S3 bucket name for Terraform state storage
state_bucket_name = "your-unique-bucket-name"
```

**File 2:** `infra-eks/deployment/backend-config.hcl`
```hcl
# Must match the value in backend.tfvars
bucket = "your-unique-bucket-name"

# Optional: Uncomment if you enable DynamoDB state locking
# dynamodb_table = "your-terraform-locks-table"
```

**Critical**: Both values **must match** exactly. The bucket name must be globally unique across all AWS accounts.

**Example:**
```hcl
state_bucket_name = "mycompany-terraform-state-bucket-eks"
bucket = "mycompany-terraform-state-bucket-eks"
```

---

### Step 2: Configure Project Name and Environment

Edit `infra-eks/deployment/common.tfvars`:

```hcl
# Project identifier (used for resource naming and tagging)
project_name = "your-project-name"

# Environment identifier: "dev" or "prod"
environment = "dev"
```

**Guidelines:**
- `project_name`: Short, lowercase, alphanumeric (e.g., `myapp`, `webapp`, `api`)
- `environment`: Must be either `"dev"` or `"prod"` (affects resource configuration)

**Example:**
```hcl
project_name = "myapp"
environment = "prod"
```

**Impact:** These values determine resource naming patterns:
- EKS Cluster: `${environment}-${project_name}-eks-cluster` → `prod-myapp-eks-cluster`
- Node Group: `${environment}-${project_name}-node-group` → `prod-myapp-node-group`
- ECR Repository: `${environment}-${project_name}-ecr-repository` → `prod-myapp-ecr-repository`

---

### Step 3: Configure Your Domain Name

Edit `infra-eks/deployment/domain.tfvars`:

```hcl
# Your root domain name (must be a domain you own)
root_domain = "yourdomain.com"
```

**Example:**
```hcl
root_domain = "example.com"
```

**What This Configures:**
- SSL Certificate will be issued for: `example.com` and `*.example.com`
- Route 53 A records will be created for: `example.com` (pointing to ALB created by Ingress)

---

### Step 4: (Optional) Change AWS Region

By default, the infrastructure deploys to `eu-west-1`. To use a different region:

**A. Update GitHub Workflows** (if using CI/CD):

Edit `.github/workflows/eks/*.yaml` files:
```yaml
env:
  AWS_REGION: your-preferred-region  # Change from eu-west-1
  TERRAFORM_VERSION: 1.10.3
  KUBECTL_VERSION: 1.28.0
  HELM_VERSION: 3.13.0
```

**B. Update Backend Configuration:**

Edit `infra-eks/deployment/backend-config.hcl` and add the region parameter:
```hcl
bucket = "your-unique-bucket-name"
region = "your-preferred-region"  # Add this line
```

**C. Update Terraform Init Commands:**

When running `terraform init` manually, specify the region:
```bash
terraform init -backend-config="../backend-config.hcl" -backend-config="region=your-preferred-region"
```

---

### Step 5: Configure GitHub Secrets (For CI/CD Only)

If you plan to use the GitHub Actions workflows, add these secrets to your repository:

**Navigate to:** GitHub Repository → Settings → Secrets and variables → Actions → New repository secret

**Required Secrets:**
- **Name:** `AWS_ACCESS_KEY_ID`
  - **Value:** Your AWS IAM user access key
- **Name:** `AWS_SECRET_ACCESS_KEY`
  - **Value:** Your AWS IAM user secret key

**IAM Permissions Required:**
The IAM user needs permissions for: VPC, EC2, EKS, ECR, ALB, Route53, ACM, IAM, CloudWatch, Auto Scaling, S3 (for state), and optionally DynamoDB (for locking).

**Security Best Practice:** Create a dedicated IAM user for CI/CD with least-privilege permissions.

---

## 3. Environment-Specific Configuration (Optional)

The infrastructure supports different resource configurations for `dev` and `prod` environments through configuration maps defined in `common.tfvars` and module-specific tfvars files.

**Default Configuration:**
The repository includes sensible defaults for both environments. For most use cases, you **do not need to modify** these values.

**Advanced Configuration:**
If you want to customize environment-specific settings (e.g., instance sizes, scaling limits, NAT gateway configuration, capacity types), refer to the [Environment Configuration Differences](../README.md#4-environment-configuration-differences) section in the main README for a complete explanation of all available settings.

**Example Settings:**
- NAT Gateway count (single vs multi-AZ)
- ECR image retention (3 images in dev, 10 in prod)
- Node Group min/max instances
- Worker node capacity type (SPOT vs ON_DEMAND)
- Pod replica counts and resource limits

---

## 4. DNS Configuration (Post-Deployment)

After deploying the Route 53 Hosted Zone (see [CI/CD Workflows - Initial Setup](CICD_WORKFLOWS.md#1-initial-setup)), you must **manually update DNS nameservers** at your domain registrar.

**Steps:**

1. **Deploy the Hosted Zone** using the `eks-deploy-hosted-zone.yaml` workflow or Terraform

2. **Retrieve Nameservers** from AWS Console:
   - Navigate to: AWS Console → Route 53 → Hosted Zones
   - Click on your hosted zone
   - Copy the 4 NS (nameserver) records, which look like:
     ```
     ns-123.awsdns-45.com
     ns-678.awsdns-90.net
     ns-1234.awsdns-56.org
     ns-5678.awsdns-12.co.uk
     ```

3. **Update DNS at Your Domain Registrar:**
   - Log in to your domain registrar (GoDaddy, Namecheap, etc.)
   - Navigate to DNS management / Nameserver settings
   - Replace existing nameservers with the 4 Route 53 nameservers
   - Save changes

4. **Wait for DNS Propagation:**
   - Propagation typically takes 5-60 minutes
   - Can take up to 48 hours in rare cases
   - **Verify propagation** before proceeding:
     ```bash
     dig NS yourdomain.com
     # or
     nslookup -type=NS yourdomain.com
     ```

5. **Proceed with SSL Certificate Deployment:**
   - Once DNS propagation is complete, the SSL certificate validation will succeed
   - The ACM certificate validation depends on functioning DNS

**Warning:** If you attempt to deploy the SSL certificate before DNS propagation completes, the validation will fail and the deployment will hang or timeout.

---

**Return to:** [Main README](../README.md) | [CI/CD Workflows](CICD_WORKFLOWS.md) | [AWS Resources Deep Dive](AWS_RESOURCES_DEEP_DIVE.md)
