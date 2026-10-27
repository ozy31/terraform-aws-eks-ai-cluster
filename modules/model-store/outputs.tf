output "bucket_name" {
  description = "Name of the model bucket."
  value       = aws_s3_bucket.models.id
}

output "bucket_arn" {
  description = "ARN of the model bucket."
  value       = aws_s3_bucket.models.arn
}

output "bucket_region" {
  description = "Region of the model bucket (passed to Mountpoint)."
  value       = aws_s3_bucket.models.region
}

output "kms_key_arn" {
  description = "KMS key encrypting model objects. Writers (CI that publishes models) need kms:GenerateDataKey on it."
  value       = aws_kms_key.models.arn
}

output "mountpoint_role_arn" {
  description = "Read-only IAM role used by the Mountpoint S3 CSI driver."
  value       = aws_iam_role.mountpoint.arn
}
