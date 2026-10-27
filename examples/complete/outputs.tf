output "model_bucket" {
  description = "Upload weights with: aws s3 sync ./Qwen3-8B s3://<bucket>/qwen/Qwen3-8B/"
  value       = module.model_store.bucket_name
}

output "endpoints" {
  description = "In-cluster OpenAI-compatible endpoints per model."
  value = {
    (module.qwen3_8b.served_model_name)  = module.qwen3_8b.endpoint
    (module.qwen3_32b.served_model_name) = module.qwen3_32b.endpoint
  }
}

output "gpu_node_pools" {
  description = "GPU NodePools created by Karpenter."
  value       = module.gpu_nodepools.node_pool_names
}
