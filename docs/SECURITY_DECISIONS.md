# Security Decisions Summary

This document provides a quick reference for intentional security decisions made in this project that may appear as findings in security scanners.

## Overview

Security scanners like Trivy and TFLint may flag certain configurations as potential security issues. This project includes **Architectural Decision Records (ADRs)** that document why certain "findings" are intentional design decisions rather than vulnerabilities.

## Quick Reference Table

| Finding | Rule ID | Status | ADR | Summary |
|---------|---------|--------|-----|---------|
| Unrestricted egress (ALB) | AVD-AWS-0104 | ✅ Accepted | [ADR-001](./adr/001-unrestricted-security-group-egress.md) | Required for AWS service access |
| Unrestricted egress (ECS Cluster) | AVD-AWS-0104 | ✅ Accepted | [ADR-001](./adr/001-unrestricted-security-group-egress.md) | Required for ECR pulls and CloudWatch |
| Unrestricted egress (ECS Tasks) | AVD-AWS-0104 | ✅ Accepted | [ADR-001](./adr/001-unrestricted-security-group-egress.md) | Required for external APIs |
| Internet-facing ALB | AVD-AWS-0053 | ✅ Accepted | [ADR-002](./adr/002-internet-facing-alb.md) | Public web application |
| AWS-managed S3 encryption | AVD-AWS-0132 | ✅ Accepted | [ADR-003](./adr/003-s3-aws-managed-encryption.md) | Cost-effective, sufficient security |

## Implemented Security Fixes

The following findings were addressed with code changes:

| Finding | Rule ID | Status | Implementation |
|---------|---------|--------|----------------|
| Container runs as root | AVD-DS-0002 | ✅ Fixed | Non-root user added to Dockerfile |
| ALB invalid headers | AVD-AWS-0052 | ✅ Fixed | `drop_invalid_header_fields = true` |
| ECR image scanning | AVD-AWS-0030 | ✅ Fixed | `scan_on_push = true` |
| ECR mutable tags | AVD-AWS-0031 | ✅ Fixed | `image_tag_mutability = "IMMUTABLE"` |
| IMDS v2 not enforced | AVD-AWS-0130 | ✅ Fixed | `http_tokens = required` |

## Suppression Configuration

Accepted findings are suppressed in [`.trivyignore`](../.trivyignore) to prevent false positives in future scans. Each suppression includes:
- Rule ID
- Affected file paths (in comments)
- Rationale statement (in comments)
- Reference to ADR (in comments)

## For Compliance Auditors

If you're reviewing this project for compliance purposes:

1. **Read the ADRs** - Each decision is documented with alternatives considered and rationale
2. **Review mitigation strategies** - Each ADR describes how risk is mitigated through other controls
3. **Check compliance mapping** - ADR-003 includes compliance standard mapping
4. **Understand the context** - These are intentional decisions, not oversights

### When These Decisions May Not Be Acceptable

The ADRs document scenarios where different decisions may be required:

- **PCI-DSS Level 1** compliance may require customer-managed KMS keys (see ADR-003)
- **Highly regulated industries** (healthcare, finance) may require restricted egress (see ADR-001)
- **Internal applications** should not use internet-facing ALBs (see ADR-002)
- **Air-gapped environments** require different architecture (see ADR-001)

## Review Schedule

These decisions should be reviewed:

| Trigger | Frequency | Action |
|---------|-----------|--------|
| Annual Review | Yearly | Re-evaluate all ADRs for relevance |
| Compliance Change | As needed | Check if new requirements invalidate decisions |
| Architecture Change | As needed | Ensure ADRs still apply to new design |
| Security Incident | Immediate | Review if incident relates to accepted risk |
| AWS Service Update | As needed | Check if new services provide better alternatives |

**Last Review:** 2025-11-28
**Next Review:** 2026-11-28

## Security Principles

While we accept certain scanner findings, our security posture is based on:

### Defense in Depth
Multiple security layers compensate for accepted risks:
- Network segmentation (public/private subnets)
- IAM least privilege
- Encryption at rest and in transit
- Container security (non-root user, image scanning)
- Monitoring and logging

### Risk-Based Approach
Decisions balance:
- **Security:** Adequate protection for data sensitivity
- **Cost:** Avoid unnecessary expenses
- **Complexity:** Maintainable solutions
- **Compliance:** Meet applicable standards

### Continuous Improvement
Security is not static:
- Regular reviews of decisions
- Update when better alternatives emerge
- Learn from security research
- Adapt to changing requirements

## Useful Commands

### Run Trivy with Suppressions
```bash
trivy config --severity HIGH,CRITICAL --ignorefile .trivyignore .
```

### Run TFLint
```bash
tflint --recursive --filter=infra/
```

### Run Pre-commit Hooks
```bash
pre-commit run --all-files
```

### Update ADRs
When updating an ADR:
1. Update the ADR markdown file
2. Update `.trivyignore` if needed
3. Update this summary document
4. Commit all changes together

## Additional Resources

- [ADR Directory](./adr/README.md) - Full list of architectural decisions
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [TFLint Documentation](https://github.com/terraform-linters/tflint)

## Questions?

If you have questions about these security decisions:
1. Read the relevant ADR for full context
2. Check if your scenario matches "When to Reconsider" sections
3. Review compliance mapping in ADR-003
4. Consider if requirements have changed since last review

Remember: These are **intentional, documented decisions**, not security oversights.
