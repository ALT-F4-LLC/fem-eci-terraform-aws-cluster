variable "domain" {
  type = string
}

variable "environment" {
  type = string
}

variable "instance_type" {
  default = "t3.medium"
  type    = string
}

variable "market_type" {
  default = "spot"
  type    = string
}

variable "name" {
  type = string
}

variable "vpc_name" {
  type = string
}
