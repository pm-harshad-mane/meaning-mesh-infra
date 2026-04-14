variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "image" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "execution_role_arn" {
  type = string
}

variable "environment_variables" {
  type = map(string)
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "assign_public_ip" {
  type    = bool
  default = false
}

variable "instance_type" {
  type    = string
  default = "m7g.4xlarge"
}

variable "instance_min_size" {
  type    = number
  default = 1
}

variable "instance_max_size" {
  type    = number
  default = 4
}

variable "instance_desired_capacity" {
  type    = number
  default = 2
}

variable "task_cpu" {
  type    = number
  default = 16384
}

variable "task_memory" {
  type    = number
  default = 32768
}

variable "service_desired_count" {
  type    = number
  default = 2
}

variable "service_min_capacity" {
  type    = number
  default = 2
}

variable "service_max_capacity" {
  type    = number
  default = 10
}
