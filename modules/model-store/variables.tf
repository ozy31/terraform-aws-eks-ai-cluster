variable "cluster_name" {
  description = "EKS cluster that mounts the model bucket."
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket holding model weights. Defaults to <cluster_name>-models-<account_id>."
  type        = string
  default     = null
}

variable "noncurrent_version_expiration_days" {
  description = "Days to keep overwritten model versions. Long enough to roll back a bad model push."
  type        = number
  default     = 30
}

variable "access_log_bucket" {
  description = "Existing bucket for S3 server access logs. null disables access logging."
  type        = string
  default     = null
}

variable "install_mountpoint_csi_driver" {
  description = "Install the Mountpoint for Amazon S3 CSI driver as an EKS managed add-on. Set false if it is already installed with its own role."
  type        = bool
  default     = true
}

variable "mountpoint_csi_driver_version" {
  description = "Add-on version for aws-mountpoint-s3-csi-driver. null takes the default version for the cluster's Kubernetes release."
  type        = string
  default     = null
}

variable "kms_deletion_window_days" {
  description = "Waiting period before the KMS key is deleted."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
