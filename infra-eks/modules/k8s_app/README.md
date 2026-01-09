# k8s_app

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.27.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_deployment.app](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment) | resource |
| [kubernetes_horizontal_pod_autoscaler_v2.app](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/horizontal_pod_autoscaler_v2) | resource |
| [kubernetes_ingress_v1.app](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/ingress_v1) | resource |
| [kubernetes_service.app](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service) | resource |
| [kubernetes_service_account.app](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [aws_lb_hosted_zone_id.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb_hosted_zone_id) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acm_certificate_arn"></a> [acm\_certificate\_arn](#input\_acm\_certificate\_arn) | ACM certificate ARN for HTTPS | `string` | `""` | no |
| <a name="input_additional_ingress_annotations"></a> [additional\_ingress\_annotations](#input\_additional\_ingress\_annotations) | Additional annotations for the Ingress resource | `map(string)` | `{}` | no |
| <a name="input_alb_scheme"></a> [alb\_scheme](#input\_alb\_scheme) | ALB scheme (internet-facing or internal) | `string` | `"internet-facing"` | no |
| <a name="input_app_name"></a> [app\_name](#input\_app\_name) | Name of the application | `string` | `"nestjs-app"` | no |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | Port the container listens on | `number` | `3000` | no |
| <a name="input_cpu_limit"></a> [cpu\_limit](#input\_cpu\_limit) | CPU limit per environment | `map(string)` | <pre>{<br/>  "dev": "250m",<br/>  "prod": "500m"<br/>}</pre> | no |
| <a name="input_cpu_request"></a> [cpu\_request](#input\_cpu\_request) | CPU request per environment | `map(string)` | <pre>{<br/>  "dev": "50m",<br/>  "prod": "250m"<br/>}</pre> | no |
| <a name="input_cpu_target_utilization"></a> [cpu\_target\_utilization](#input\_cpu\_target\_utilization) | Target CPU utilization percentage for HPA | `number` | `70` | no |
| <a name="input_ecr_repository_url"></a> [ecr\_repository\_url](#input\_ecr\_repository\_url) | ECR repository URL for the application image | `string` | n/a | yes |
| <a name="input_enable_autoscaling"></a> [enable\_autoscaling](#input\_enable\_autoscaling) | Enable Horizontal Pod Autoscaler | `bool` | `true` | no |
| <a name="input_enable_https"></a> [enable\_https](#input\_enable\_https) | Enable HTTPS on the ALB | `bool` | `true` | no |
| <a name="input_enable_ingress"></a> [enable\_ingress](#input\_enable\_ingress) | Enable Ingress resource creation | `bool` | `true` | no |
| <a name="input_enable_session_affinity"></a> [enable\_session\_affinity](#input\_enable\_session\_affinity) | Enable session affinity (sticky sessions) | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (dev, prod) | `string` | n/a | yes |
| <a name="input_environment_variables"></a> [environment\_variables](#input\_environment\_variables) | Environment variables for the application | `map(string)` | `{}` | no |
| <a name="input_health_check_path"></a> [health\_check\_path](#input\_health\_check\_path) | Health check endpoint path | `string` | `"/health"` | no |
| <a name="input_iam_role_arn"></a> [iam\_role\_arn](#input\_iam\_role\_arn) | IAM role ARN for IRSA (IAM Roles for Service Accounts) | `string` | `""` | no |
| <a name="input_image_tag"></a> [image\_tag](#input\_image\_tag) | Docker image tag to deploy | `string` | `"latest"` | no |
| <a name="input_max_replicas"></a> [max\_replicas](#input\_max\_replicas) | Maximum number of replicas for HPA per environment | `map(number)` | <pre>{<br/>  "dev": 5,<br/>  "prod": 10<br/>}</pre> | no |
| <a name="input_memory_limit"></a> [memory\_limit](#input\_memory\_limit) | Memory limit per environment | `map(string)` | <pre>{<br/>  "dev": "512Mi",<br/>  "prod": "1024Mi"<br/>}</pre> | no |
| <a name="input_memory_request"></a> [memory\_request](#input\_memory\_request) | Memory request per environment | `map(string)` | <pre>{<br/>  "dev": "128Mi",<br/>  "prod": "512Mi"<br/>}</pre> | no |
| <a name="input_memory_target_utilization"></a> [memory\_target\_utilization](#input\_memory\_target\_utilization) | Target memory utilization percentage for HPA | `number` | `80` | no |
| <a name="input_min_replicas"></a> [min\_replicas](#input\_min\_replicas) | Minimum number of replicas for HPA per environment | `map(number)` | <pre>{<br/>  "dev": 2,<br/>  "prod": 3<br/>}</pre> | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace for the application | `string` | `"default"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Name of the project | `string` | n/a | yes |
| <a name="input_replica_count"></a> [replica\_count](#input\_replica\_count) | Number of pod replicas per environment | `map(number)` | <pre>{<br/>  "dev": 2,<br/>  "prod": 3<br/>}</pre> | no |
| <a name="input_root_domain_name"></a> [root\_domain\_name](#input\_root\_domain\_name) | Root domain name for the Ingress resource | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_url"></a> [alb\_url](#output\_alb\_url) | URL of the Application Load Balancer (if ingress enabled and HTTPS) |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | Canonical hosted zone ID of the ALB |
| <a name="output_container_image"></a> [container\_image](#output\_container\_image) | Container image used in the deployment |
| <a name="output_container_port"></a> [container\_port](#output\_container\_port) | Port the container listens on |
| <a name="output_deployment_name"></a> [deployment\_name](#output\_deployment\_name) | Name of the Kubernetes deployment |
| <a name="output_deployment_namespace"></a> [deployment\_namespace](#output\_deployment\_namespace) | Namespace of the Kubernetes deployment |
| <a name="output_deployment_replicas"></a> [deployment\_replicas](#output\_deployment\_replicas) | Number of replicas in the deployment |
| <a name="output_health_check_path"></a> [health\_check\_path](#output\_health\_check\_path) | Health check endpoint path |
| <a name="output_hpa_max_replicas"></a> [hpa\_max\_replicas](#output\_hpa\_max\_replicas) | Maximum number of replicas for HPA (if enabled) |
| <a name="output_hpa_min_replicas"></a> [hpa\_min\_replicas](#output\_hpa\_min\_replicas) | Minimum number of replicas for HPA (if enabled) |
| <a name="output_hpa_name"></a> [hpa\_name](#output\_hpa\_name) | Name of the Horizontal Pod Autoscaler (if enabled) |
| <a name="output_ingress_hostname"></a> [ingress\_hostname](#output\_ingress\_hostname) | Hostname of the ingress load balancer (if enabled) |
| <a name="output_ingress_name"></a> [ingress\_name](#output\_ingress\_name) | Name of the Kubernetes ingress (if enabled) |
| <a name="output_service_account_name"></a> [service\_account\_name](#output\_service\_account\_name) | Name of the Kubernetes service account |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Name of the Kubernetes service |
| <a name="output_service_namespace"></a> [service\_namespace](#output\_service\_namespace) | Namespace of the Kubernetes service |
| <a name="output_service_type"></a> [service\_type](#output\_service\_type) | Type of the Kubernetes service |
<!-- END_TF_DOCS -->
