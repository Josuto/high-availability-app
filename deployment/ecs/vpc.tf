module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"

  name = "vpc-module-demo"
  cidr = "10.0.0.0/16"

  azs             = ["${var.AWS_REGION}a", "${var.AWS_REGION}b", "${var.AWS_REGION}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true # Required to be true as otherwise the EC2 instance is not able to register in the ECS cluster or access any other AWS external service e.g., SSM
  single_nat_gateway = true # Creates one NAT GW for all AZs (cheaper option in test envs not requiring high-availability)
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = "prod"
  }
}