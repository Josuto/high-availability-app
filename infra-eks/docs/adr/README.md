# Architectural Decision Records (ADRs)

This directory contains Architectural Decision Records (ADRs) documenting important architectural and security decisions made for this EKS-based infrastructure project.

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

### Infrastructure & Deployment

| ADR | Title | Status | Summary |
|-----|-------|--------|---------|
| [001](./001-kubernetes-resource-management-via-terraform.md) | Kubernetes Resource Management via Terraform | Accepted | Use Terraform Kubernetes provider instead of raw YAML manifests |

## Relationship to ECS Implementation

This EKS infrastructure shares foundational components with the ECS implementation (`infra-ecs/`) but uses Kubernetes-specific approaches for application deployment. Some ADRs may reference parallel decisions made in the ECS implementation.

## When to Create a New ADR

Create a new ADR when:
- Making a significant architectural decision
- Choosing between multiple viable alternatives
- Security scanner flags a finding you intentionally accept
- Future team members would benefit from understanding the rationale
- Compliance auditors may question the decision
- Diverging from community best practices for valid reasons

## Reviewing ADRs

ADRs should be reviewed:
- When requirements change (new compliance needs, budget changes)
- When new alternatives become available (new AWS services, Kubernetes features)
- During major architecture revisions
- When Kubernetes version upgrades introduce new capabilities
- Annually as part of security and architecture review

## EKS-Specific Considerations

When creating ADRs for EKS infrastructure, consider:
- **Kubernetes Native vs AWS Native**: Trade-offs between Kubernetes patterns and AWS services
- **Portability**: Multi-cloud considerations vs AWS-specific optimizations
- **Operational Complexity**: Kubernetes learning curve vs functionality
- **Cost**: EKS control plane costs, worker node optimization, Spot instances
- **Tooling**: kubectl/Helm vs Terraform, GitOps patterns

## References

- [ADR GitHub Organization](https://adr.github.io/)
- [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
