module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "${var.environment}-${var.project_name}-vpc"
  cidr   = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true                                    # Required to enable private EC2 instance to register into an ECS cluster as well as to access other AWS services (e.g., SSM) and the Internet for updates/patches
  single_nat_gateway = var.single_nat_gateway[var.environment] # Creates one NAT GW for all AZs (cheaper option in test envs not requiring high-availability); set to false in PROD environments
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Project     = var.project_name
    Environment = var.environment
  }
}
