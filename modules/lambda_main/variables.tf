variable "environment" {
  type = string
}

variable "role_arn" {
  type = string
}

variable "package_file" {
  type = string
}

variable "environment_variables" {
  type = map(string)
}
