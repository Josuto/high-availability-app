# ADR 003: S3 Bucket Encryption with AWS-Managed Keys

## Status
Accepted

## Context
The Terraform state bucket requires encryption at rest to protect sensitive infrastructure state data. AWS S3 supports multiple encryption options: no encryption, AWS-managed keys (SSE-S3), and customer-managed keys (SSE-KMS). Trivy security scanner flagged the use of AWS-managed keys as a HIGH security finding (AVD-AWS-0132), recommending customer-managed KMS keys for enhanced control.

## Decision
We will **use AWS-managed keys (SSE-S3 with AES256)** for Terraform state bucket encryption in production, with no encryption in development.

**Affected Resource:**
- `infra/deployment/backend/s3.tf` - S3 bucket server-side encryption configuration

**Current Implementation:**
```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
  count  = var.environment == "prod" ? 1 : 0
  bucket = aws_s3_bucket.terraform_state_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # AWS-managed keys
    }
    bucket_key_enabled = true
  }
}
```

## Alternatives Considered

### Alternative 1: Customer-Managed KMS Keys (SSE-KMS)
**Description:** Create and manage KMS Customer Master Key (CMK) for S3 encryption

**Configuration:**
```hcl
resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
  bucket = aws_s3_bucket.terraform_state_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }
  }
}
```

**Pros:**
- Full control over key rotation policy
- Detailed CloudTrail logs of key usage
- Can revoke access by disabling key
- Cross-account access control
- Meets certain compliance requirements (PCI-DSS, HIPAA)
- Can use key for multiple resources

**Cons:**
- **Cost:** $1.00/month per key + $0.03 per 10,000 API requests
- **Complexity:** Must manage key lifecycle, rotation, and access policies
- **Risk:** Accidental key deletion causes permanent data loss
- **Overhead:** Need separate keys per environment (dev/prod)
- **Latency:** Additional API calls for each S3 operation
- **Operational:** Requires KMS permissions in IAM policies

**Annual Cost Estimate:**
- 2 keys (dev, prod): $24/year
- API requests (est. 100k/year): $0.30/year
- **Total:** ~$25/year + operational overhead

### Alternative 2: No Encryption
**Description:** Disable encryption entirely

**Pros:**
- No cost
- Simplest implementation
- No key management

**Cons:**
- ❌ Violates security best practices
- ❌ Non-compliant with most standards
- ❌ Terraform state contains sensitive data (passwords, keys, IPs)
- ❌ Unacceptable risk for production
- ❌ AWS recommends encryption for all S3 buckets

**Status:** Not viable for production environments

### Alternative 3: S3 Bucket Keys with AWS-Managed Keys (Current Choice)
**Description:** Use AWS-managed keys (SSE-S3) with S3 Bucket Keys enabled

**Configuration:**
```hcl
sse_algorithm      = "AES256"
bucket_key_enabled = true  # Reduces costs by reducing KMS requests
```

**Pros:**
- ✅ **No cost** for encryption
- ✅ **Automatic key management** by AWS
- ✅ **Zero operational overhead**
- ✅ **Secure:** 256-bit AES encryption
- ✅ **Compliant:** Meets most security standards
- ✅ **Automatic rotation:** AWS handles key rotation
- ✅ **No risk** of key deletion
- ✅ **Bucket key enabled:** Reduces S3 API calls

**Cons:**
- Less granular access control than CMK
- No cross-account key sharing
- Limited audit logging (basic CloudTrail only)
- Cannot revoke access via key disablement

## Rationale for Decision

We chose AWS-managed keys because:

1. **Cost Efficiency**
   - $0 encryption cost vs $25+/year for KMS
   - No ongoing API request charges
   - Significant savings at scale

2. **Sufficient Security**
   - AES-256 encryption is cryptographically secure
   - AWS manages key rotation automatically
   - Keys are never exposed or accessible
   - Meets security requirements for non-regulated industries

3. **Zero Operational Overhead**
   - No key lifecycle management
   - No risk of accidental key deletion
   - No additional IAM policies required
   - Automatic and transparent

4. **Terraform State Use Case**
   - State bucket is single-account resource
   - No cross-account access requirements
   - No compliance mandate for CMK
   - S3 bucket policies provide access control

5. **Risk Assessment**
   - Terraform state is sensitive but not regulated data
   - S3 bucket policies and IAM provide access control
   - VPC endpoints can be used for private access
   - Version control and DynamoDB locking protect integrity

## Security Posture

Our Terraform state security relies on multiple layers:

### 1. Encryption at Rest (This ADR)
- **AWS-managed AES-256 encryption**
- Protects against physical disk theft
- Bucket keys enabled for efficiency

### 2. Encryption in Transit
- **TLS 1.2+ enforced** via bucket policy
- All API calls encrypted
- Certificate validation required

### 3. Access Control
- **IAM policies:** Restrict which users/roles can access
- **S3 bucket policy:** Deny unencrypted uploads
- **MFA Delete:** Can be enabled for additional protection

### 4. State Locking
- **DynamoDB table:** Prevents concurrent modifications
- **Versioning:** Maintains state history
- **Lifecycle rules:** Manages retention

### 5. Network Security
- State bucket is not public
- Can use VPC endpoints for private access
- CloudTrail logging of all API calls

## When to Upgrade to CMK

Consider upgrading to customer-managed KMS keys if:

1. **Compliance Requirements**
   - PCI-DSS Level 1 compliance required
   - HIPAA encryption key requirements
   - SOC 2 Type II with specific key management controls
   - Industry regulations mandate CMK

2. **Organizational Policies**
   - Company policy requires customer-managed keys
   - Multi-account organization needs centralized key management
   - Detailed audit requirements for every key use

3. **Cross-Account Access**
   - Need to share state bucket across AWS accounts
   - Centralized security account manages all keys

4. **Enhanced Audit Requirements**
   - Need CloudTrail logs for every encryption/decryption operation
   - Compliance audits require granular key usage tracking

## Compliance Mapping

| Standard | SSE-S3 (Current) | SSE-KMS Required? |
|----------|------------------|-------------------|
| AWS Well-Architected | ✅ Compliant | No |
| NIST 800-53 | ✅ Compliant | No |
| SOC 2 Type II | ✅ Compliant | Depends on controls |
| ISO 27001 | ✅ Compliant | No |
| PCI-DSS Level 2-4 | ✅ Compliant | No |
| PCI-DSS Level 1 | ⚠️ Review required | Possibly |
| HIPAA | ⚠️ Review required | Possibly |
| FedRAMP | ❌ May not comply | Likely |

## Consequences

### Positive
- No encryption costs
- Zero key management overhead
- Automatic key rotation by AWS
- No risk of key deletion
- Sufficient security for most use cases
- Simple implementation

### Negative
- Less control over key lifecycle
- Cannot revoke access via key disablement
- Limited audit logging
- May not meet certain compliance requirements

### Neutral
- Trade-off between cost/complexity and control
- Appropriate for non-regulated data
- Can upgrade to CMK later if requirements change

## Migration Path

If future requirements demand customer-managed keys:

1. Create KMS CMK with rotation enabled
2. Update S3 bucket encryption configuration
3. Existing objects remain encrypted with old key (transparent)
4. New objects use new CMK
5. Optional: Re-encrypt existing objects with new key

Migration is **non-breaking** and can be done at any time.

## Related Decisions
- S3 bucket versioning and lifecycle policies (implemented)
- DynamoDB state locking (implemented)
- S3 bucket public access blocking (implemented)

## References
- [AWS S3 Encryption](https://docs.aws.amazon.com/AmazonS3/latest/userguide/serv-side-encryption.html)
- [AWS KMS Pricing](https://aws.amazon.com/kms/pricing/)
- [Trivy AVD-AWS-0132](https://avd.aquasec.com/misconfig/avd-aws-0132)
- [Terraform Backend Configuration](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [AWS S3 Security Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
