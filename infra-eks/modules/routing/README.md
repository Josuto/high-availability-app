# routing

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.27.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_route53_record.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_zone_id"></a> [alb\_zone\_id](#input\_alb\_zone\_id) | Canonical hosted zone ID of the ALB | `string` | n/a | yes |
| <a name="input_hosted_zone_id"></a> [hosted\_zone\_id](#input\_hosted\_zone\_id) | Route 53 Hosted Zone ID where the DNS record will be created. | `string` | `""` | no |
| <a name="input_ingress_hostname"></a> [ingress\_hostname](#input\_ingress\_hostname) | Hostname of the ingress load balancer (if enabled) | `string` | n/a | yes |
| <a name="input_root_domain_name"></a> [root\_domain\_name](#input\_root\_domain\_name) | Fully qualified domain name (FQDN) to associate with the application ALB (e.g. api.example.com). | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
