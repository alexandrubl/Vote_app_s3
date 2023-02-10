variable "subnet_ips" {
    description = " subnet_ips"
    type        = string
    default     = "10.10.1.0/24"
}

variable "subnet_names" {
    description = " subnet_names"
    type        = string
    default     = "subnetA"
}

variable "subnet_azs" {
    description = " subnet_azs"
    type        = string
    default     = "us-east-1a"
}