# An AWS Elastic Load Balancer (ELB) that is used to distribute the incoming traffic to the containers hosted at the EC2 instances included at the EC2 cluster
resource "aws_elb" "dummy-app-elb" {
  name                        = "dummy-app-elb"
  subnets                     = [ aws_subnet.main-public-1.id, aws_subnet.main-public-2.id ] # ELB present in two subnets to ensure high availability
  security_groups             = [aws_security_group.dummy-app-elb-security-group.id] # the security group for the ELB
  cross_zone_load_balancing   = true # distribute the load across all instances in all subnets
  connection_draining         = true # wait for all connections to finish before deregistering an instance
  connection_draining_timeout = 400 # wait for 400 seconds before deregistering an instance

  listener {
    instance_port     = var.CONTAINER_PORT # port the containers listen on
    instance_protocol = "HTTP"
    lb_port           = 80 # the ELB listens on port 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:${var.CONTAINER_PORT}/" # check if the container is healty
    interval            = 30 # check every 30 seconds whether the server is healthy
    timeout             = 5
    healthy_threshold   = 2 # two consecutive checks before must be successful before sending traffic to the server
    unhealthy_threshold = 2 # two consecutive checks must fail before stopping traffic to the server
  }

  tags = {
    Name = "dummy-app-elb"
  }
}

# Output the DNS name of the ELB to enable making requests to the ELB, which in turn will distribute 
# the requests to the containers hosted at the EC2 instances
output "ELB" {
  value = aws_elb.dummy-app-elb.dns_name
}