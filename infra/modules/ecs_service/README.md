# ecs_service

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.22.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.cluster_lg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_service.ecs_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.ecs_service_taskdef](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role.ecs_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ecs_execution_role_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_security_group.ecs_tasks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.alb_to_tasks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_ecs_task_definition.ecs_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_task_definition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_security_group_id"></a> [alb\_security\_group\_id](#input\_alb\_security\_group\_id) | The ID of the ALB's security group | `string` | n/a | yes |
| <a name="input_alb_target_group_id"></a> [alb\_target\_group\_id](#input\_alb\_target\_group\_id) | The target group to link the ECS service to | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"eu-west-1"` | no |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | Name of the app container to be deployed | `string` | n/a | yes |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | Port the app container is available from | `number` | `3000` | no |
| <a name="input_cpu_limit"></a> [cpu\_limit](#input\_cpu\_limit) | The limit of usage of CPU on a task/container | `number` | `256` | no |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | Upper limit of health tasks that must be running during deployment | `number` | `200` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | Lower limit of healthy tasks that must be running during deployment so that the service remains available | `number` | `100` | no |
| <a name="input_ecr_app_image"></a> [ecr\_app\_image](#input\_ecr\_app\_image) | App ECR Image. Specified at the infra creation/destruction pipelines | `string` | n/a | yes |
| <a name="input_ecs_capacity_provider_name"></a> [ecs\_capacity\_provider\_name](#input\_ecs\_capacity\_provider\_name) | The name of the ECS Capacity Provider that enables app auto-scaling | `string` | n/a | yes |
| <a name="input_ecs_cluster_arn"></a> [ecs\_cluster\_arn](#input\_ecs\_cluster\_arn) | ECS cluster ARN | `string` | n/a | yes |
| <a name="input_ecs_task_desired_count"></a> [ecs\_task\_desired\_count](#input\_ecs\_task\_desired\_count) | The number of tasks that you want to run for this service | `number` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | The environment to deploy to (dev or prod). | `string` | `"dev"` | no |
| <a name="input_log_group"></a> [log\_group](#input\_log\_group) | AWS Cloudwatch log group | `string` | n/a | yes |
| <a name="input_memory_limit"></a> [memory\_limit](#input\_memory\_limit) | The limit of usage of memory on a task/container | `number` | `128` | no |
| <a name="input_ordered_placement_strategies"></a> [ordered\_placement\_strategies](#input\_ordered\_placement\_strategies) | A map of placement strategies (type and field) to apply, keyed by environment (dev/prod). | <pre>map(list(object({<br/>    type  = string<br/>    field = string<br/>  })))</pre> | <pre>{<br/>  "dev": [<br/>    {<br/>      "field": "cpu",<br/>      "type": "binpack"<br/>    }<br/>  ],<br/>  "prod": [<br/>    {<br/>      "field": "attribute:ecs.availability-zone",<br/>      "type": "spread"<br/>    },<br/>    {<br/>      "field": "attribute:instanceId",<br/>      "type": "spread"<br/>    }<br/>  ]<br/>}</pre> | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | The name of the project this module belongs to | `string` | n/a | yes |
| <a name="input_task_role_arn"></a> [task\_role\_arn](#input\_task\_role\_arn) | Specifies the ARN of an IAM role that the app will assume | `string` | `""` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID | `string` | n/a | yes |
| <a name="input_vpc_private_subnets"></a> [vpc\_private\_subnets](#input\_vpc\_private\_subnets) | The list of existing VPC private subnets | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ecs_service_name"></a> [ecs\_service\_name](#output\_ecs\_service\_name) | n/a |
<!-- END_TF_DOCS -->
