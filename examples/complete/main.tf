locals {
  tags = {
    Project     = "ai-cluster"
    Environment = "prod"
    ManagedBy   = "terraform"
    Repository  = "github.com/ozy31/terraform-aws-eks-ai-cluster"
  }
}

################################################################################
# GPU capacity: spot-first inference pool, on-demand training pool
################################################################################

module "gpu_nodepools" {
  source = "../../modules/gpu-nodepools"

  cluster_name   = var.cluster_name
  node_role_name = var.karpenter_node_role_name

  node_pools = {
    inference = {
      instance_families = ["g6", "g6e", "g5"]
      max_gpus_per_node = 4
      gpu_limit         = 16
      weight            = 50
    }
    training = {
      instance_families    = ["p5", "p4d"]
      capacity_types       = ["on-demand"]
      max_gpus_per_node    = 8
      gpu_limit            = 16
      consolidation_policy = "WhenEmpty"
      consolidate_after    = "5m"
      disruption_nodes     = "0"
    }
  }

  tags = local.tags
}

################################################################################
# Device plugin + DCGM metrics + GPU alerts
################################################################################

module "gpu_stack" {
  source = "../../modules/gpu-stack"

  depends_on = [module.gpu_nodepools]
}

################################################################################
# Model weights in S3, mounted read-only through Mountpoint
################################################################################

module "model_store" {
  source = "../../modules/model-store"

  cluster_name = var.cluster_name

  tags = local.tags
}

################################################################################
# Two models: an 8B chat model on one L4/A10G, a 32B model sharded across 4 GPUs
################################################################################

module "qwen3_8b" {
  source = "../../modules/inference"

  name = "qwen3-8b"

  model = {
    s3_prefix     = "qwen/Qwen3-8B"
    served_name   = "qwen3-8b"
    max_model_len = 16384
    extra_args    = ["--enable-prefix-caching"]
  }

  model_bucket = {
    name   = module.model_store.bucket_name
    region = module.model_store.bucket_region
  }

  autoscaling = {
    min_replicas = 1
    max_replicas = 6
  }

  depends_on = [module.gpu_stack]
}

module "qwen3_32b" {
  source = "../../modules/inference"

  name = "qwen3-32b"

  model = {
    s3_prefix            = "qwen/Qwen3-32B-FP8"
    served_name          = "qwen3-32b"
    tensor_parallel_size = 4
    max_model_len        = 32768
  }

  model_bucket = {
    name   = module.model_store.bucket_name
    region = module.model_store.bucket_region
  }

  resources = {
    cpu    = "16"
    memory = "128Gi"
    shm    = "32Gi"
  }

  # Internal batch traffic only: scale to zero overnight and wake on gateway traffic.
  autoscaling = {
    min_replicas     = 0
    max_replicas     = 2
    cooldown_seconds = 1800
    wake_query       = "sum(rate(envoy_cluster_upstream_rq_total{envoy_cluster_name=~\".*qwen3-32b.*\"}[2m]))"
  }

  depends_on = [module.gpu_stack]
}
