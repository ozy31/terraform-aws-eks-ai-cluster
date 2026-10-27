output "node_class_name" {
  description = "Name of the GPU EC2NodeClass."
  value       = "gpu"
}

output "node_pool_names" {
  description = "Names of the GPU NodePools. Workloads select one with the ai.platform/pool node label."
  value       = keys(var.node_pools)
}

output "gpu_taint" {
  description = "Taint carried by every GPU node. GPU workloads need a matching toleration."
  value = {
    key    = "nvidia.com/gpu"
    value  = "true"
    effect = "NoSchedule"
  }
}
