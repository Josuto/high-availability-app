# Required the outputs from a child module (that defined under the 'modules' folder) are not automatically promoted to the state file of 
# the root module (i.e., the module where this file is included). Otherwise, the variables included in any GH Actions pipeline or Terraform 
# variables will appear to be empty.

output "alb_target_group_id" {
  value = module.alb.alb_target_group_id
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "alb_hosted_zone_id" {
  value = module.alb.alb_hosted_zone_id
}