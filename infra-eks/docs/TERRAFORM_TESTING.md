# Terraform Testing

## 1. Running Tests

**Test Runner**: `infra-eks/run-tests.sh`

```bash
cd infra-eks/
chmod +x run-tests.sh
./run-tests.sh
```

**What It Does**:
- Runs all `.tftest.hcl` files in `tests/unit/` using `terraform test`
- Tests run in **plan mode** (no real AWS resources created)
- Uses mock AWS credentials
- Outputs test results to `test.log`

**CI/CD Integration**: Tests automatically run in the `test-eks-terraform-modules` job before any deployment.

---

## 2. Troubleshooting

For general troubleshooting advice on Terraform testing (test failures, permission errors, Terraform version issues, etc.), refer to the [Troubleshooting section in docs/TESTING.md](../../docs/TESTING.md#troubleshooting).

This section covers EKS-specific testing issues:

### EKS Cluster Module Fails to Initialize

If you see "Failed to initialize eks_cluster for validation", you need mock AWS credentials:

```bash
# The eks_cluster module has data sources that require AWS credentials
export AWS_ACCESS_KEY_ID="mock-access-key"
export AWS_SECRET_ACCESS_KEY="mock-secret-key" # pragma: allowlist secret
export AWS_DEFAULT_REGION="eu-west-1"
./run-tests.sh
```

**Why this is needed:**
- EKS modules may query AWS resources or require provider initialization
- Terraform requires credentials to initialize the AWS provider, even for validation
- Mock credentials satisfy this requirement without making actual AWS API calls
- CI/CD pipeline automatically provides these credentials

### Kubernetes Provider Authentication Issues

If you see authentication errors with the Kubernetes provider in tests:

```bash
# Tests use mock Kubernetes provider configuration
# Ensure you're not connected to a real cluster during testing
unset KUBECONFIG
./run-tests.sh
```

**Why this matters:**
- Tests should use mock credentials, not real cluster access
- `kubeconfig` environment variable can interfere with test execution
- Tests run in plan mode only and don't need actual cluster connectivity

---

## 3. Test Files Explained

All test files use Terraform's native testing framework (introduced in Terraform 1.6+). Tests use mock AWS credentials and validate module configuration without creating real resources.

---

### 3.1. ecr.tftest.hcl

**Module Tested**: `modules/ecr/` <br>
**Purpose**: Validates ECR repository configuration, security settings, and lifecycle policies.

**Test Suites**:

1. **ecr_repository_basic_configuration**
   - Verifies repository naming: `${environment}-${project_name}-ecr-repository`
   - Confirms image tag mutability is `IMMUTABLE`
   - **Why**: Prevents tag overwrites, ensures reliable rollbacks
   - Validates scan_on_push is enabled for vulnerability scanning

2. **ecr_repository_tagging**
   - Confirms project name is included in repository name
   - **Why**: Maintains naming consistency

3. **ecr_lifecycle_policy_exists**
   - Validates lifecycle policy is attached to repository
   - Confirms policy is defined (length > 0)
   - **Why**: Ensures automated image cleanup

4. **ecr_lifecycle_policy_untagged_images**
   - Validates policy includes rule for untagged images
   - Confirms retention count of 1 for untagged images
   - **Why**: Aggressively cleans up temporary/failed builds

5. **ecr_lifecycle_policy_dev_retention**
   - Validates policy uses `dev-` tag prefix
   - Confirms retention count matches dev configuration (e.g., 5 images)
   - **Why**: Environment-specific retention for cost management

6. **ecr_lifecycle_policy_prod_retention**
   - Validates policy uses `prod-` tag prefix
   - Confirms retention count matches prod configuration (e.g., 20 images)
   - **Why**: Deeper rollback history for production

7. **ecr_variable_validation_retention_count**
   - Tests valid retention counts are accepted
   - **Why**: Input validation

8. **ecr_variable_validation_environment**
   - Tests valid environment values are accepted (prod)
   - **Why**: Environment validation

---

### 3.2. ssl.tftest.hcl

**Module Tested**: `modules/ssl/` <br>
**Purpose**: Validates ACM certificate configuration, DNS validation, SANs, and lifecycle rules.

**Test Suites**:

1. **ssl_certificate_basic_configuration**
   - Verifies certificate domain matches root domain
   - Confirms DNS validation method (not email)
   - **Why**: DNS validation enables automation
   - Validates wildcard SAN is included

2. **ssl_validation_records_configuration**
   - Confirms all validation records use correct hosted zone ID
   - Validates `allow_overwrite = true` for redeployments
   - Checks TTL is 60 seconds
   - **Why**: Fast DNS propagation for validation

3. **ssl_certificate_validation_configuration**
   - Validates validation records are created
   - **Why**: Ensures validation workflow can complete

4. **ssl_production_environment**
   - Tests production certificate has correct domain
   - **Why**: Environment-specific validation

5. **ssl_san_wildcard_coverage**
   - Validates root domain is primary certificate domain
   - Confirms wildcard SAN covers all subdomains
   - **Why**: Single certificate for root and all subdomains

6. **ssl_validation_method_dns_only**
   - Confirms DNS validation is used (critical for automation)
   - Ensures email validation is NOT used
   - **Why**: Email validation requires manual intervention

---

### 3.3. hosted_zone.tftest.hcl

**Module Tested**: `modules/hosted_zone/` <br>
**Purpose**: Validates Route 53 Hosted Zone configuration and environment-specific settings.

**Test Suites**:

1. **hosted_zone_basic_configuration**
   - Verifies hosted zone name matches root domain
   - Validates descriptive comment is set
   - **Why**: Clear identification of zone purpose

2. **hosted_zone_dev_force_destroy**
   - Confirms force_destroy is enabled for dev environment
   - **Why**: Allows cleanup during development without manual intervention

3. **hosted_zone_prod_force_destroy**
   - Confirms force_destroy is disabled for prod environment
   - **Why**: Prevents accidental deletion of production domain

4. **hosted_zone_tagging**
   - Validates Project, Environment, ManagedBy, and Module tags
   - **Why**: Resource organization and cost allocation

5. **hosted_zone_subdomain**
   - Tests hosted zone accepts subdomain as root domain name
   - **Why**: Supports flexible domain configurations

6. **hosted_zone_environment_validation**
   - Tests valid environment values are accepted
   - **Why**: Environment validation

7. **hosted_zone_custom_force_destroy_values**
   - Tests custom force_destroy values are respected
   - **Why**: Configuration flexibility

---

### 3.4. eks_cluster.tftest.hcl

**Module Tested**: `modules/eks_cluster/` <br>
**Purpose**: Validates EKS cluster, IAM roles, security groups, and environment-specific configurations.

**Test Suites**:

1. **eks_cluster_basic_configuration**
   - Verifies EKS cluster naming: `${environment}-${project_name}-eks-cluster`
   - Validates Kubernetes version matches input
   - **Why**: Naming consistency and version control

2. **eks_cluster_vpc_configuration**
   - Confirms private endpoint access is enabled
   - Validates public endpoint access (enabled for dev by default)
   - Checks all private and public subnets are used
   - **Why**: Proper network isolation and accessibility

3. **eks_cluster_prod_endpoint_access**
   - Confirms public endpoint access is disabled for prod
   - **Why**: Enhanced security for production clusters

4. **eks_cluster_logging_configuration**
   - Validates all 5 log types are enabled (api, audit, authenticator, controllerManager, scheduler)
   - **Why**: Comprehensive observability

5. **eks_cluster_cloudwatch_log_group_dev**
   - Validates log group naming convention
   - Confirms 7-day retention for dev
   - **Why**: Cost optimization in development

6. **eks_cluster_cloudwatch_log_group_prod**
   - Confirms 30-day retention for prod
   - **Why**: Compliance and troubleshooting in production

7. **eks_cluster_encryption_without_kms**
   - Verifies no encryption config when KMS key not provided
   - **Why**: AWS-managed encryption by default

8. **eks_cluster_iam_role**
   - Validates IAM role naming convention
   - Confirms EKS service trust relationship
   - **Why**: Proper cluster permissions

9. **eks_cluster_iam_policies**
   - Validates AmazonEKSClusterPolicy is attached
   - Confirms AmazonEKSVPCResourceController is attached
   - **Why**: Required policies for cluster operation

10. **eks_cluster_security_group**
    - Validates cluster security group is in correct VPC
    - Confirms naming convention and egress rules
    - **Why**: Network security and connectivity

11. **eks_nodes_security_group**
    - Validates nodes security group configuration
    - Confirms naming convention
    - **Why**: Worker node network security

12. **eks_security_group_rules**
    - Validates cluster ingress from nodes on port 443
    - Confirms node-to-node communication
    - Validates cluster-to-nodes communication on high ports (1025-65535)
    - **Why**: Required Kubernetes control plane communication

13. **eks_cluster_tags**
    - Validates Project, Environment, ManagedBy, and Module tags
    - **Why**: Resource organization and cost tracking

14. **eks_cluster_with_alb_security_group**
    - Tests ALB ingress rule creation when ALB SG provided
    - Validates NodePort range (30000-32767)
    - **Why**: ALB to worker nodes communication for Ingress

---

### 3.5. eks_node_group.tftest.hcl

**Module Tested**: `modules/eks_node_group/` <br>
**Purpose**: Validates node group configuration, scaling, IAM roles, and environment-specific settings.

**Test Suites**:

1. **eks_node_group_basic_configuration**
   - Verifies node group naming follows cluster pattern
   - Validates association with correct cluster
   - Confirms Kubernetes version and instance type
   - **Why**: Consistency and version alignment

2. **eks_node_group_dev_scaling_config**
   - Validates dev scaling: desired=2, min=1, max=3
   - **Why**: Cost-optimized scaling for development

3. **eks_node_group_prod_scaling_config**
   - Validates prod scaling: desired=3, min=2, max=10
   - **Why**: Higher baseline capacity for production

4. **eks_node_group_capacity_type_dev**
   - Confirms SPOT instances for dev environment
   - **Why**: Cost savings in development

5. **eks_node_group_capacity_type_prod**
   - Confirms ON_DEMAND instances for prod environment
   - **Why**: Reliability in production

6. **eks_node_group_update_config**
   - Validates max unavailable during updates
   - **Why**: Controlled rolling updates

7. **eks_node_group_ami_and_disk**
   - Validates AMI type (AL2_x86_64)
   - Confirms disk encryption is enabled
   - Validates volume type is gp3
   - Checks disk size configuration
   - **Why**: Security and performance

8. **eks_node_group_labels**
   - Validates Kubernetes node labels for Environment and Project
   - **Why**: Pod scheduling and workload placement

9. **eks_node_group_launch_template**
   - Validates launch template attachment
   - Confirms IMDSv2 is required
   - Checks IMDS hop limit is 2 (required for EKS)
   - Validates detailed monitoring is enabled
   - **Why**: Security and observability

10. **eks_node_group_iam_role**
    - Validates IAM role naming convention
    - Confirms EC2 service trust relationship
    - **Why**: Worker node permissions

11. **eks_node_group_iam_policies**
    - Validates AmazonEKSWorkerNodePolicy is attached
    - Confirms AmazonEKS_CNI_Policy is attached
    - Validates AmazonEC2ContainerRegistryReadOnly is attached
    - Confirms AmazonSSMManagedInstanceCore is attached
    - **Why**: Required managed policies for node functionality

12. **eks_node_group_custom_policies**
    - Validates custom CloudWatch logging policy
    - Confirms custom autoscaling policy
    - **Why**: Enhanced logging and Cluster Autoscaler support

13. **eks_node_group_tags**
    - Validates Project, Environment, ManagedBy, and Module tags
    - **Why**: Resource organization

14. **eks_node_group_subnets**
    - Validates node group uses all private subnets
    - **Why**: Multi-AZ deployment for high availability

---

### 3.6. aws_lb_controller.tftest.hcl

**Module Tested**: `modules/aws_lb_controller/` <br>
**Purpose**: Validates OIDC provider, IAM configuration, and Helm chart deployment.

**Test Suites**:

1. **aws_lb_controller_oidc_provider**
   - Validates OIDC provider client ID list includes sts.amazonaws.com
   - Confirms OIDC provider URL matches cluster issuer
   - Checks thumbprint list is present
   - **Why**: Required for IAM Roles for Service Accounts (IRSA)

2. **aws_lb_controller_iam_policy**
   - Validates IAM policy naming convention
   - Confirms policy has descriptive description
   - Checks policy content is not empty
   - **Why**: Permissions for ALB creation and management

3. **aws_lb_controller_iam_role**
   - Validates IAM role naming convention
   - Confirms role is created
   - **Why**: IRSA role for Load Balancer Controller

4. **aws_lb_controller_iam_role_policy_attachment**
   - Validates policy is attached to correct role
   - **Why**: Links permissions to service account

5. **aws_lb_controller_service_account_default**
   - Validates default service account name: aws-load-balancer-controller
   - Confirms default namespace: kube-system
   - **Why**: Standard Kubernetes service account

6. **aws_lb_controller_service_account_custom**
   - Tests custom service account name and namespace
   - **Why**: Configuration flexibility

7. **aws_lb_controller_helm_release_default**
   - Validates Helm release name, chart, repository
   - Confirms default namespace (kube-system)
   - Checks version, wait settings, and timeout
   - **Why**: Proper Helm deployment configuration

8. **aws_lb_controller_helm_release_custom**
   - Tests custom Helm release name, version, and timeout
   - **Why**: Configuration flexibility

9. **aws_lb_controller_helm_values**
   - Validates Helm values contain cluster name and VPC ID
   - Confirms service account creation is disabled (pre-created)
   - **Why**: Correct Load Balancer Controller configuration

10. **aws_lb_controller_tags**
    - Validates custom tags on OIDC provider, IAM policy, and role
    - **Why**: Resource organization

11. **aws_lb_controller_oidc_provider_tags**
    - Validates OIDC provider Name tag follows convention
    - **Why**: Clear resource identification

12. **aws_lb_controller_variable_validation**
    - Tests non-standard environment values are accepted
    - **Why**: Module flexibility

---

### 3.7. k8s_app.tftest.hcl

**Module Tested**: `modules/k8s_app/` <br>
**Purpose**: Validates Kubernetes application deployment, service, HPA, ingress, and environment-specific configurations.

**Test Suites**:

1. **k8s_deployment_basic_configuration**
   - Validates deployment naming: `${app_name}-deployment`
   - Confirms default namespace
   - Checks replica count for dev (2)
   - **Why**: Basic deployment configuration

2. **k8s_deployment_prod_replicas**
   - Validates higher replica count for prod (3)
   - **Why**: Increased capacity for production

3. **k8s_deployment_container_configuration**
   - Validates container image URL and tag
   - Confirms container name matches app name
   - Checks container port and protocol (TCP)
   - **Why**: Correct container configuration

4. **k8s_deployment_resources_dev**
   - Validates memory request (128Mi) and CPU request (50m) for dev
   - **Why**: Resource requests for scheduling

5. **k8s_deployment_resources_prod**
   - Validates memory limit (1024Mi) and CPU limit (500m) for prod
   - **Why**: Resource limits prevent resource exhaustion

6. **k8s_deployment_health_probes**
   - Validates liveness and readiness probe paths
   - Confirms probe ports and initial delays (30s liveness, 10s readiness)
   - **Why**: Pod health monitoring and traffic routing

7. **k8s_deployment_security_context**
   - Validates run as non-root user
   - Confirms privilege escalation is disabled
   - Checks run as user 1001 and fs_group 1000
   - **Why**: Pod security best practices

8. **k8s_deployment_rolling_update_strategy**
   - Validates RollingUpdate strategy
   - Confirms max unavailable and max surge (25%)
   - **Why**: Zero-downtime deployments

9. **k8s_service_account**
   - Validates service account naming: `${app_name}-sa`
   - Confirms automount token is enabled
   - **Why**: Kubernetes service identity

10. **k8s_service_account_with_iam_role**
    - Validates IAM role ARN annotation for IRSA
    - **Why**: AWS permissions for pods

11. **k8s_service_configuration**
    - Validates service naming and NodePort type
    - Confirms port 80 maps to container port
    - Checks session affinity disabled by default
    - **Why**: Internal load balancing

12. **k8s_service_session_affinity**
    - Validates ClientIP session affinity when enabled
    - **Why**: Sticky sessions for stateful applications

13. **k8s_hpa_enabled**
    - Validates HPA naming: `${app_name}-hpa`
    - Confirms min/max replicas for dev (2-5)
    - Checks HPA targets deployment
    - **Why**: Automatic horizontal scaling

14. **k8s_hpa_prod_scaling**
    - Validates min/max replicas for prod (3-10)
    - **Why**: Higher scaling capacity for production

15. **k8s_ingress_enabled**
    - Validates ingress naming: `${app_name}-ingress`
    - Confirms ALB ingress class
    - Checks internet-facing scheme and IP target type
    - **Why**: External access via ALB

16. **k8s_ingress_https_configuration**
    - Validates HTTPS listener configuration
    - Confirms SSL redirect and ACM certificate ARN
    - **Why**: Secure HTTPS communication

17. **k8s_deployment_labels**
    - Validates Kubernetes standard labels (app.kubernetes.io/name, instance, version)
    - Confirms environment label
    - **Why**: Label best practices for Kubernetes resources

---

**Return to:** [Main README](../README.md) | [Prerequisites and Setup](PREREQUISITES_AND_SETUP.md) | [AWS Resources Deep Dive](AWS_RESOURCES_DEEP_DIVE.md) | [CI/CD Workflows](CICD_WORKFLOWS.md)
