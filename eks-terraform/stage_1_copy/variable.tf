variable "region" {
  default = "ap-south-1"
}

variable "cluster_name" {
  default = "demo-cluster"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}


variable "env" {
  type = string
}

variable "private_subnet_cidrs" {
  description = "CIDR_BLOCKS"
  type  = list(string)
}

