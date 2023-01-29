variable "namespace" {
  type    = string
  default = "playground"
}

variable "stage" {
  type    = string
  default = "dev"
}

variable "name" {
  type    = string
  default = "k8s"
}

variable "region" {
  type    = string
}

variable "vpc_id" {
  type    = string
}

variable "subnet_ids" {
  type    = list(string)
}

variable "size" {
  type    = number
}

