variable "cluster_name" {
    description = "Name of the ECS cluster"
    default     = "my-ecs"
}

variable "ecs_instance_type" {
    description = "Type of the AWS EC2 instances to be deployed at ECS"
    default     = "t2.micro" 
}

# module.vpc.vpc_id
variable "vpc_id" {
    description = "VPC ID"
    type        = string
}

# module.vpc.private_subnets
variable "vpc_private_subnets" {
    description = "The list of existing VPC private subnets"
    type        = list(string) 
}