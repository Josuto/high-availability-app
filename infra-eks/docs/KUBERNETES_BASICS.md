# Kubernetes and AWS EKS Basics

## Kubernetes Main Concepts

If new to Kubernetes, understand these concepts:

1. **Pod**: Smallest deployable unit (1+ containers)
2. **Deployment**: Manages replicas of pods
3. **Service**: Internal load balancer + DNS
4. **Ingress**: External load balancer (ALB)
5. **ConfigMap**: Configuration data
6. **Secret**: Sensitive data
7. **HPA**: Horizontal Pod Autoscaler

## AWS EKS Specifics

If new to AWS EKS, know these components:

1. **AWS Load Balancer Controller**: Creates ALBs from Ingress
2. **VPC CNI**: Gives pods VPC IP addresses
3. **IAM Roles for Service Accounts (IRSA)**: Pod-level IAM
4. **EBS CSI Driver**: For persistent volumes
5. **CloudWatch Container Insights**: For monitoring

## Learning Resources

- [Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [AWS EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [AWS EKS Workshop](https://www.eksworkshop.com/)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

---

**Return to:** [Main README](../README.md) | [Prerequisites and Setup](PREREQUISITES_AND_SETUP.md) | [AWS Resources Deep Dive](AWS_RESOURCES_DEEP_DIVE.md)
