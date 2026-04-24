# Human-readable prefix applied to Name tags and some resource names.
variable "project_name" {
  description = "Prefix for resource names."
  type        = string
}

# Region string used to build regional VPC endpoint DNS/service names (e.g. com.amazonaws.us-east-1.ec2).
variable "aws_region" {
  description = "AWS region (used for VPC endpoint service names)."
  type        = string
}

# Overall IPv4 space for the dedicated VPC.
variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.42.0.0/16"
}

# Exactly two /24 (or other) blocks, index 0 and 1 mapped to distinct AZs in main.tf.
variable "private_subnet_cidrs" {
  description = "Two CIDR blocks for private subnets in distinct AZs."
  type        = list(string)
  default     = ["10.42.1.0/24", "10.42.2.0/24"]
}
