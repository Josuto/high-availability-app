variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
}

variable "ecs_max_utilisation" {
  description = "Max utilisation of the ECS cluster percentage-wise. The ECS calculates its current utilisation by masuring the total CPU/memory capacity reserved by the running tasks against the total available capacity of all EC2 instances of the cluster"
  default     = 90
}