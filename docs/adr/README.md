# Architectural Decision Records (ADRs)

This directory contains Architectural Decision Records (ADRs) documenting important architectural and security decisions made for this project.

## What is an ADR?

An Architectural Decision Record (ADR) is a document that captures an important architectural decision made along with its context and consequences. ADRs help teams understand why certain decisions were made, especially when revisiting them in the future.

## Format

Each ADR follows this structure:
- **Status**: Accepted, Proposed, Deprecated, or Superseded
- **Context**: The issue motivating this decision
- **Decision**: The chosen solution
- **Alternatives Considered**: Other options that were evaluated
- **Rationale**: Why this decision was made
- **Consequences**: The positive, negative, and neutral impacts

## Index of ADRs

### Security Decisions

| ADR | Title | Status | Summary |
|-----|-------|--------|---------|
| [001](./001-unrestricted-security-group-egress.md) | Unrestricted Security Group Egress Rules | Accepted | Use 0.0.0.0/0 egress rules for operational requirements |
| [002](./002-internet-facing-alb.md) | Internet-Facing Application Load Balancer | Accepted | Deploy ALB as internet-facing for public web application |
| [003](./003-s3-aws-managed-encryption.md) | S3 Bucket Encryption with AWS-Managed Keys | Accepted | Use SSE-S3 instead of customer-managed KMS keys |

### Testing & Quality Assurance

| ADR | Title | Status | Summary |
|-----|-------|--------|---------|
| [004](./004-terraform-module-testing-strategy.md) | Terraform Module Testing Strategy | Accepted | Selective unit testing based on module complexity and criticality |

## Relationship to Security Scanning

These ADRs document **intentional design decisions** that security scanners (Trivy, tfsec) may flag as findings. Each ADR:

1. Acknowledges the security scanner finding
2. Evaluates alternative approaches
3. Documents the rationale for accepting the risk
4. Describes mitigation strategies

The corresponding Trivy rules are suppressed in `.trivyignore.yaml` to prevent false positives in future scans.

## When to Create a New ADR

Create a new ADR when:
- Making a significant architectural decision
- Choosing between multiple viable alternatives
- Security scanner flags a finding you intentionally accept
- Future team members would benefit from understanding the rationale
- Compliance auditors may question the decision

## Reviewing ADRs

ADRs should be reviewed:
- When requirements change (new compliance needs, budget changes)
- When new alternatives become available (new AWS services)
- During major architecture revisions
- Annually as part of security review

## References

- [ADR GitHub Organization](https://adr.github.io/)
- [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
