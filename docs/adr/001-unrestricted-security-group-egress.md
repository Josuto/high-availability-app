# ADR 001: Unrestricted Security Group Egress Rules

## Status
Accepted

## Context
Our ECS infrastructure requires security groups for:
- Application Load Balancer (ALB)
- ECS Cluster EC2 instances
- ECS Service tasks

Each of these components needs outbound internet connectivity for various operational requirements. Trivy security scanner flagged unrestricted egress rules (0.0.0.0/0) as a CRITICAL security finding (AVD-AWS-0104).

## Decision
We will **maintain unrestricted egress rules (0.0.0.0/0)** for all security groups in the infrastructure.

**Affected Resources:**
- `infra/modules/alb/alb-securitygroup.tf` - ALB egress
- `infra/modules/ecs_cluster/ecs-securitygroup.tf` - Cluster egress
- `infra/modules/ecs_service/task-securitygroup.tf` - Task egress

## Alternatives Considered

### Alternative 1: Restrict to Specific CIDR Blocks
**Description:** Limit egress to known IP ranges (e.g., AWS service endpoints, specific APIs)

**Pros:**
- Reduces attack surface
- Follows principle of least privilege
- Meets compliance requirements for highly regulated environments

**Cons:**
- Requires maintaining extensive whitelist of IP ranges
- AWS services use dynamic IP ranges that change frequently
- Breaks functionality when new services or endpoints are added
- Significant operational overhead
- Does not work with third-party APIs with dynamic IPs

### Alternative 2: Use VPC Endpoints
**Description:** Keep traffic within AWS network using VPC endpoints for AWS services

**Pros:**
- Traffic never leaves AWS network
- Better performance
- No data transfer charges for AWS services
- More secure than internet routing

**Cons:**
- Additional cost (~$0.01/hour per endpoint = ~$7.20/month each)
- Requires 3+ endpoints minimum (ECR API, ECR DKR, CloudWatch Logs)
- Still need internet egress for third-party services
- Increased infrastructure complexity
- Does not eliminate need for 0.0.0.0/0 egress completely

### Alternative 3: Egress-Only Internet Gateway with NAT
**Description:** Use controlled egress through NAT Gateway with logging

**Pros:**
- Centralized egress point
- Can log all outbound traffic
- Maintains unrestricted egress functionality

**Cons:**
- Already implemented (using NAT Gateway in private subnets)
- Does not address the security group rule concern
- NAT Gateway costs (~$32/month + data transfer)

## Rationale for Decision

We chose unrestricted egress because our containers require:

1. **ECR Access** - Pull Docker images from Elastic Container Registry
   - ECR uses dynamic AWS IP ranges that change frequently
   - Blocking prevents container deployments

2. **CloudWatch Logs** - Send application and system logs
   - Critical for monitoring and debugging
   - Uses dynamic AWS endpoints

3. **External APIs** - Application functionality requirements
   - Third-party services with dynamic IPs
   - Cannot maintain whitelist of all possible destinations

4. **Package Updates** - Security patches and dependencies
   - Operating system updates from public repositories
   - npm/pnpm package installations

5. **Cost vs Benefit**
   - VPC endpoints would cost $21.60+/month
   - Minimal security benefit since application still needs internet access
   - Does not eliminate egress requirement

## Security Mitigations

While allowing unrestricted egress, we maintain security through:

1. **Network Segmentation**
   - Resources in private subnets with no direct internet access
   - All egress routed through NAT Gateway

2. **Ingress Controls**
   - Strict ingress rules limit what can reach our resources
   - Only ALB accepts public traffic

3. **IAM Policies**
   - Least privilege IAM roles restrict AWS API access
   - Separate roles for different components

4. **Container Security**
   - Non-root user in containers (ADR implemented)
   - Image scanning enabled on ECR
   - Regular security updates

5. **Monitoring**
   - CloudWatch Logs for all components
   - VPC Flow Logs for network traffic analysis
   - AWS GuardDuty for threat detection

## Consequences

### Positive
- Containers can access required AWS services
- Application can call external APIs
- Simplified infrastructure management
- No additional VPC endpoint costs
- Faster deployment and updates

### Negative
- Broader attack surface if container is compromised
- Compliance audits may require additional justification
- Cannot prevent data exfiltration through network controls alone

### Neutral
- Must rely on other security layers (IAM, monitoring, container security)
- Acceptable trade-off for operational flexibility

## Compliance Notes
This design is acceptable for:
- Standard web applications
- Development and staging environments
- Production environments without strict egress requirements

This design may NOT be acceptable for:
- PCI-DSS Level 1 compliance
- Highly regulated industries (healthcare, finance) with strict egress controls
- Air-gapped or isolated network requirements

If compliance requirements change, revisit Alternative 2 (VPC Endpoints) with additional egress controls.

## Related Decisions
- ADR 002: Internet-Facing ALB (related to ingress strategy)

## References
- [AWS Security Group Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html)
- [Trivy AVD-AWS-0104](https://avd.aquasec.com/misconfig/aws-vpc-no-public-egress-sgr)
- [AWS VPC Endpoints Pricing](https://aws.amazon.com/privatelink/pricing/)
