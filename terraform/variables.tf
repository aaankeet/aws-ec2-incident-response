
variable "project_name" {
  description = "Name of the EC2 incident response project"
  type        = string
  default     = "aws-ec2-incident-response"
}

variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "lab"
}

variable "instance_type" {
  description = "EC2 instance type for the test environment"
  type        = string
  default     = "t3.micro"
}
