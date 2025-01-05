# Purpose: This file is used to get the latest Amazon ECS-optimized AMI for Amazon Linux 2023.
data "aws_ssm_parameter" "ecs-ami-linux-2023" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

data "aws_ami" "ecs-ami-linux-2023" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.ecs-ami-linux-2023.value]
  }
}
