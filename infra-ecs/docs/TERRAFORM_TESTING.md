# Terraform Testing

## 1. Running Tests

**Test Runner**: `infra-ecs/run-tests.sh`

```bash
cd infra-ecs/
chmod +x run-tests.sh
./run-tests.sh
```

**What It Does**:
- Runs all `.tftest.hcl` files in `tests/unit/` using `terraform test`
- Tests run in **plan mode** (no real AWS resources created)
- Uses mock AWS credentials
- Outputs test results to `test.log`

**CI/CD Integration**: Tests automatically run in the `test-terraform-modules` job before any deployment.

**Pre-Push Hook Integration**: Tests also run automatically via the `terraform-ecs-tests` pre-push hook when you push changes that affect Terraform files in the `infra-ecs/` directory. See [../../docs/TESTING.md](../../docs/TESTING.md#pre-commit-and-pre-push-hook-integration) for details.

---

## 2. Troubleshooting

For general troubleshooting advice on Terraform testing (test failures, permission errors, Terraform version issues, etc.), refer to the [Troubleshooting section in docs/TESTING.md](../../docs/TESTING.md#troubleshooting).

This section covers ECS-specific testing issues:

### ECS Cluster Module Fails to Initialize

If you see "Failed to initialize ecs_cluster for validation", you need mock AWS credentials:

```bash
# The ecs_cluster module has data sources that require AWS credentials
export AWS_ACCESS_KEY_ID="mock-access-key"
export AWS_SECRET_ACCESS_KEY="mock-secret-key" # pragma: allowlist secret
export AWS_DEFAULT_REGION="eu-west-1"
./run-tests.sh
```

**Why this is needed:**
- The ecs_cluster module queries AWS SSM Parameter Store for ECS-optimized AMI IDs
- Terraform requires credentials to initialize the AWS provider, even for validation
- Mock credentials satisfy this requirement without making actual AWS API calls
- CI/CD pipeline automatically provides these credentials

---

## 3. Test Files Explained

All test files use Terraform's native testing framework (introduced in Terraform 1.6+). Tests use mock AWS credentials and validate module configuration without creating real resources.

---

### 3.1. alb.tftest.hcl

**Module Tested**: `modules/alb/` <br>
**Purpose**: Validates ALB configuration, listeners, target groups, and security groups.

**Test Suites**:

1. **alb_valid_configuration**
   - Verifies ALB naming convention: `${environment}-${project_name}-alb`
   - Confirms ALB is internet-facing (`internal = false`)
   - Validates security setting: `drop_invalid_header_fields = true`
   - Checks deletion protection is disabled for dev environment

2. **alb_production_configuration**
   - Confirms deletion protection is enabled for prod environment
   - **Why**: Prevents accidental deletion of production load balancer

3. **alb_listeners_configured**
   - **HTTPS Listener (Port 443)**:
     - Port and protocol validation
     - SSL policy check: `ELBSecurityPolicy-TLS13-1-2-Res-2021-06`
     - **Why**: Ensures modern, secure TLS configuration
   - **HTTP Listener (Port 80)**:
     - Validates redirect to HTTPS (type: `redirect`)
     - Confirms 301 permanent redirect status code
     - **Why**: Enforces HTTPS for all traffic

4. **alb_target_group_configured**
   - Validates target group port matches container port
   - Confirms HTTP protocol for backend communication
   - Checks deregistration delay configuration (default: 30s)
   - Validates health check path and matcher (HTTP 200)
   - **Why**: Ensures proper traffic routing and health monitoring

5. **alb_security_group_rules**
   - Confirms security group is in correct VPC
   - Validates HTTPS (443) and HTTP (80) ingress rules
   - Confirms egress rules allow outbound traffic to ECS tasks
   - **Why**: Ensures proper network access control

6. **alb_tags_applied**
   - Validates ALB resource is created with a name
   - **Why**: Confirms basic resource creation

---

### 3.2. ecr.tftest.hcl

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

### 3.3. ecs_cluster.tftest.hcl

**Module Tested**: `modules/ecs_cluster/` <br>
**Purpose**: Validates ECS cluster, Auto Scaling Group, Launch Template, and IAM configuration.

**Data Overrides**: Tests use `override_data` blocks to mock SSM parameter and AMI data sources (avoids real AWS API calls).

**Test Suites**:

1. **ecs_cluster_basic_configuration**
   - Verifies ECS cluster naming: `${environment}-${project_name}-ecs-cluster`
   - **Why**: Naming consistency

2. **ecs_asg_configuration**
   - Validates ASG min and max size match configured values
   - Confirms EC2 health check type with 300s grace period
   - Checks scale-in protection is disabled for dev
   - Validates ASG is deployed in all private subnets
   - Confirms `AmazonECSManaged` tag is present
   - **Why**: This tag is critical for Capacity Provider integration

3. **ecs_asg_production_configuration**
   - Confirms scale-in protection is enabled for prod
   - **Why**: Protects running tasks from premature termination

4. **ecs_launch_template_configuration**
   - Validates instance type matches configuration
   - Confirms ECS-optimized AMI is used
   - Checks IMDSv2 is required (`http_tokens = "required"`)
   - **Why**: Enhanced security for instance metadata access
   - Validates IMDS endpoint is enabled
   - Confirms IAM instance profile and security group are attached

5. **ecs_security_group_configuration**
   - Validates security group is in correct VPC
   - Confirms egress rule allows all protocols
   - **Why**: Instances need outbound access for ECS Agent, image pulls, patching

6. **ecs_iam_configuration**
   - Validates IAM role and instance profile are created
   - Confirms EC2 policy is attached
   - Validates SSM managed policy is attached
   - **Why**: Enables Systems Manager Session Manager access

7. **ecs_tags_applied**
   - Validates Project and Environment tags are applied to ASG
   - **Why**: Resource organization and cost allocation

---

### 3.4. ecs_service.tftest.hcl

**Module Tested**: `modules/ecs_service/` <br>
**Purpose**: Validates ECS task definition, service configuration, auto-scaling, and security.

**Test Suites**:

1. **ecs_service_basic_configuration**
   - Verifies ECS service naming: `${environment}-${project_name}-ecs-service`
   - Validates desired count matches input
   - Confirms capacity provider strategy is configured
   - **Why**: Ensures service uses Capacity Provider for EC2 scaling

2. **ecs_task_definition_configuration**
   - Validates task definition family matches container name
   - Confirms CPU and memory limits match configuration
   - Checks network mode is `awsvpc`
   - **Why**: Required for awsvpc networking mode and ENI assignment
   - Validates container definitions include correct ECR image
   - Confirms correct container port is exposed
   - **Why**: Regex validation ensures image and port are in JSON definition

3. **ecs_service_deployment_configuration**
   - Validates minimum healthy percent (50%)
   - Confirms maximum percent (200%)
   - **Why**: Allows rolling updates with temporary over/under-provisioning

4. **ecs_service_load_balancer_integration**
   - Confirms load balancer configuration exists
   - **Why**: Ensures ALB integration for traffic distribution

5. **ecs_service_security_group**
   - Validates security group is in correct VPC
   - Confirms security group has a name
   - **Why**: Basic security group creation check

6. **ecs_cloudwatch_logs**
   - Validates CloudWatch log group matches configuration
   - **Why**: Ensures application logs are written to correct location

7. **ecs_iam_roles**
   - Confirms task execution role is created
   - Validates trust relationship includes `ecs-tasks.amazonaws.com`
   - **Why**: Allows ECS service to assume role for image pull and logging

---

### 3.5. ssl.tftest.hcl

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

**Return to:** [Main README](../README.md) | [Prerequisites and Setup](PREREQUISITES_AND_SETUP.md) | [AWS Resources Deep Dive](AWS_RESOURCES_DEEP_DIVE.md) | [CI/CD Workflows](CICD_WORKFLOWS.md)
