# ADR 002: Internet-Facing Application Load Balancer

## Status
Accepted

## Context
Our web application needs to be accessible to end users over the internet. The Application Load Balancer (ALB) can be configured as either internet-facing (publicly accessible) or internal (VPC-only). Trivy security scanner flagged the internet-facing ALB as a HIGH security finding (AVD-AWS-0053), warning about potential accidental exposure of internal assets.

## Decision
We will **deploy the ALB as internet-facing** (`internal = false`) to allow public access to our web application.

**Affected Resource:**
- `infra/modules/alb/alb.tf` - ALB configuration

## Alternatives Considered

### Alternative 1: Internal ALB with VPN/Direct Connect
**Description:** Deploy ALB as internal and require VPN or AWS Direct Connect for access

**Pros:**
- No public IP exposure
- All traffic stays within private network
- Highest security posture
- Ideal for internal corporate applications

**Cons:**
- Blocks all public internet users from accessing the application
- Requires VPN infrastructure (~$36+/month for Client VPN)
- Poor user experience (requires VPN client installation)
- Not suitable for public-facing web applications
- Defeats the purpose of a web application

### Alternative 2: Internal ALB with CloudFront
**Description:** Use internal ALB with CloudFront as public-facing edge

**Pros:**
- CloudFront provides additional DDoS protection
- Better performance through edge caching
- Can restrict ALB to only accept CloudFront traffic
- Geographic content distribution

**Cons:**
- Additional complexity in architecture
- CloudFront costs (~$0.085/GB + request charges)
- Still exposes application to internet (just via CloudFront)
- Overkill for applications without global audience
- Doesn't fundamentally change security posture

### Alternative 3: Direct EC2 with Public IPs
**Description:** Skip ALB entirely and assign public IPs to EC2/ECS instances

**Pros:**
- Simpler architecture
- Lower cost (no ALB fees)
- Direct access to instances

**Cons:**
- No load balancing or high availability
- No SSL/TLS termination at edge
- Each instance needs public IP
- Manual health checks and failover
- Exposes instances directly to internet (worse security)
- No Web Application Firewall (WAF) capability

## Rationale for Decision

We chose an internet-facing ALB because:

1. **Application Purpose**
   - Public web application that must be accessible to anyone on the internet
   - Not an internal corporate application
   - No VPN requirement for end users

2. **Security Through Design**
   - ALB acts as security boundary between internet and private resources
   - ECS tasks remain in private subnets with no public IPs
   - SSL/TLS termination at ALB protects backend communication
   - Security groups restrict ALB to only HTTPS (443) and HTTP (80) for redirects

3. **High Availability**
   - ALB distributes traffic across multiple Availability Zones
   - Automatic health checks and failover
   - No single point of failure

4. **Cost Effectiveness**
   - Standard approach for public web applications
   - No additional VPN or CloudFront costs
   - ALB cost (~$16/month + data transfer) is necessary baseline

5. **DDoS Protection**
   - AWS Shield Standard (automatic, no cost)
   - Rate limiting capabilities
   - CloudWatch metrics for monitoring

## Security Mitigations

While exposing ALB to the internet, we maintain security through:

1. **Network Architecture**
   - ALB in public subnets (must be for internet access)
   - ECS tasks in private subnets (no direct internet exposure)
   - Security group rules restrict ALB ingress to ports 80 and 443 only

2. **SSL/TLS Configuration**
   - HTTPS listener with ACM certificate
   - Modern TLS policy: `ELBSecurityPolicy-TLS13-1-2-Res-2021-06`
   - HTTP automatically redirects to HTTPS (301)

3. **Header Security**
   - `drop_invalid_header_fields = true` (implemented via ADR)
   - Prevents header-based attacks

4. **Application Layer Security**
   - Can add AWS WAF if needed in future
   - Application-level authentication and authorization
   - Rate limiting at application level

5. **Monitoring and Alerting**
   - ALB access logs (can be enabled)
   - CloudWatch metrics and alarms
   - AWS GuardDuty for threat detection

## Trivy Finding Context

**Trivy Warning:** "Load balancer is exposed publicly"

This is a **warning, not a vulnerability**. Trivy includes this check to prevent *accidental* exposure of internal resources. In our case:
- ✅ Exposure is **intentional** and **required**
- ✅ This is a **public web application**
- ✅ Proper security controls are in place

The Trivy finding serves as a reminder to review whether public exposure is intentional, which we have confirmed it is.

## Consequences

### Positive
- Application is accessible to intended users
- High availability across multiple AZs
- SSL/TLS termination at edge
- Protection layer between internet and backend
- Standard industry practice for web applications

### Negative
- ALB is exposed to internet scanning and potential attacks
- Must maintain security posture at multiple layers
- Subject to DDoS attempts (mitigated by AWS Shield)

### Neutral
- Trade-off between accessibility and security is expected
- Same risk profile as any public web application
- Acceptable risk for intended use case

## When to Reconsider

This decision should be reconsidered if:
1. Application becomes internal-only (company portal, admin tools)
2. Global audience requires CDN (consider CloudFront)
3. Frequent DDoS attacks occur (consider AWS Shield Advanced)
4. Compliance requires additional edge security (consider WAF)
5. Zero-trust architecture is adopted (consider AWS App Mesh)

## Future Enhancements

Optional security improvements to consider:
- **AWS WAF** - Add Web Application Firewall for OWASP Top 10 protection
- **CloudFront** - Add CDN for global performance and additional DDoS protection
- **ALB Access Logs** - Enable for security audit trail
- **Cognito** - Add authentication at ALB level if needed

## Related Decisions
- ADR 001: Unrestricted Security Group Egress (related to network security strategy)

## References
- [AWS ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Trivy AVD-AWS-0053](https://avd.aquasec.com/misconfig/avd-aws-0053)
- [AWS Shield Standard](https://aws.amazon.com/shield/)
- [AWS Well-Architected Framework - Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/)
