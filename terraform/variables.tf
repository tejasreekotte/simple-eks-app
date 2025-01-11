variable "aws_region" {
  description = "AWS region for the infrastructure"
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  default     = "ascode-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.123.0.0/16"
}

variable "azs" {
  description = "Availability zones"
  default     = ["us-west-2a", "us-west-2b"]
}

variable "public_subnets" {
  description = "Public subnet CIDRs"
  default     = ["10.123.1.0/24", "10.123.2.0/24"]
}

variable "private_subnets" {
  description = "Private subnet CIDRs"
  default     = ["10.123.3.0/24", "10.123.4.0/24"]
}

variable "intra_subnets" {
  description = "Intra subnet CIDRs"
  default     = ["10.123.5.0/24", "10.123.6.0/24"]
}
