#####################################
# VPC Module Configuration
#####################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.5.1"

  name = "${var.environment}-${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  # NAT Gateway configuration
  enable_nat_gateway = true                                    # Required for private subnets to access internet
  single_nat_gateway = var.single_nat_gateway[var.environment] # Single NAT for dev (cheaper), one per AZ for prod (HA)
  enable_vpn_gateway = false

  # DNS support
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags for EKS
  # These tags are required by AWS Load Balancer Controller and EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb"                                                   = "1"
    "kubernetes.io/cluster/${var.environment}-${var.project_name}-eks-cluster" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                                          = "1"
    "kubernetes.io/cluster/${var.environment}-${var.project_name}-eks-cluster" = "shared"
  }

  tags = {
    Terraform   = "true"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Module      = "vpc"
  }
}
