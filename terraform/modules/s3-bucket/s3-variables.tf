variable "bucket_name" {
  type        = string
  description = "Globally unique name for the bucket"
}

variable "env" {
  type        = string
  description = "Environment name, used for tagging"
}

variable "default_tags" {
  type        = map(string)
  description = "Default tags to apply to all resources"
}

variable "force_destroy" {
  type        = bool
  description = "Allow Terraform to delete the bucket even if there are objects in it"
  default     = true
}