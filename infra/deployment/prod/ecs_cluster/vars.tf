variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
}

variable "cpu_scale_up_alarm_thresold" {
  description = "The percentage of CPU utilisation that makes the scale up alarm go off"
  default     = 70
}

variable "cpu_scale_down_alarm_thresold" {
  description = "The percentage of CPU utilisation that makes the scale down alarm go off"
  default     = 25
}

variable "cpu_alarm_notification_email" {
  description = "The email to notify to when a CPU utilisation alarm goes off"
  default     = "josu.martinez@gmail.com"
}