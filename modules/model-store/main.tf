data "aws_caller_identity" "current" {}

locals {
  bucket_name = coalesce(var.bucket_name, "${var.cluster_name}-models-${data.aws_caller_identity.current.account_id}")
}

################################################################################
# KMS key for model weights
################################################################################

resource "aws_kms_key" "models" {
  description             = "Model weights for EKS cluster ${var.cluster_name}"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_deletion_window_days

  tags = var.tags
}

resource "aws_kms_alias" "models" {
  name          = "alias/${var.cluster_name}-models"
  target_key_id = aws_kms_key.models.key_id
}

################################################################################
# S3 bucket
################################################################################

resource "aws_s3_bucket" "models" {
  bucket = local.bucket_name

  tags = var.tags
}

resource "aws_s3_bucket_ownership_controls" "models" {
  bucket = aws_s3_bucket.models.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "models" {
  bucket = aws_s3_bucket.models.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning is the rollback story: a bad model push is undone by restoring the
# previous object versions, not by re-uploading 100 GB.
resource "aws_s3_bucket_versioning" "models" {
  bucket = aws_s3_bucket.models.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "models" {
  bucket = aws_s3_bucket.models.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.models.arn
    }
    # Model files are read in many ranged GETs; a bucket key avoids one KMS call per request.
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "models" {
  bucket = aws_s3_bucket.models.id

  rule {
    id     = "expire-old-model-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.models]
}

resource "aws_s3_bucket_logging" "models" {
  count = var.access_log_bucket != null ? 1 : 0

  bucket        = aws_s3_bucket.models.id
  target_bucket = var.access_log_bucket
  target_prefix = "s3/${local.bucket_name}/"
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.models.arn,
      "${aws_s3_bucket.models.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "models" {
  bucket = aws_s3_bucket.models.id
  policy = data.aws_iam_policy_document.bucket.json

  depends_on = [aws_s3_bucket_public_access_block.models]
}

################################################################################
# Read-only role for the Mountpoint S3 CSI driver (EKS Pod Identity)
#
# The driver mounts the bucket read-only; inference pods never hold S3
# credentials themselves.
################################################################################

data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "read_models" {
  statement {
    sid       = "ListModels"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.models.arn]
  }

  statement {
    sid       = "ReadModels"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.models.arn}/*"]
  }

  statement {
    sid       = "DecryptModels"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.models.arn]
  }
}

resource "aws_iam_role" "mountpoint" {
  name               = "${var.cluster_name}-s3-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json

  tags = var.tags
}

resource "aws_iam_role_policy" "mountpoint" {
  name   = "read-models"
  role   = aws_iam_role.mountpoint.id
  policy = data.aws_iam_policy_document.read_models.json
}

resource "aws_eks_addon" "mountpoint" {
  count = var.install_mountpoint_csi_driver ? 1 : 0

  cluster_name  = var.cluster_name
  addon_name    = "aws-mountpoint-s3-csi-driver"
  addon_version = var.mountpoint_csi_driver_version

  pod_identity_association {
    role_arn        = aws_iam_role.mountpoint.arn
    service_account = "s3-csi-driver-sa"
  }

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = var.tags

  depends_on = [aws_iam_role_policy.mountpoint]
}
