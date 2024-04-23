
variable "iam_access_key" {
  description = "access key of the iam user that got creaed from ../iam/main.tf file"
}

variable "iam_secret_key" {
  description = "secret key of the iam user that got creaed from ../iam/main.tf file"
}

variable "vpc_cidr" {
  type = string
  default = "10.11.0.0/20"
}

variable "private_subnet_1a" {
  type = string
  default = "10.11.0.0/22"
}

variable "private_subnet_1b" {
  type = string
  default = "10.11.4.0/22"
}

variable "public_subnet_1a" {
  type = string
  default = "10.11.8.0/22"
}

variable "public_subnet_1b" {
  type = string
  default = "10.11.12.0/22"
}

variable "rt_cidr_all" {
  type = string
  default = "0.0.0.0/0"
}