output "endpoint" {
  description = "In-cluster OpenAI-compatible base URL."
  value       = "http://${var.name}.${var.namespace}.svc.cluster.local:8000/v1"
}

output "served_model_name" {
  description = "Model name clients send in requests."
  value       = var.model.served_name
}

output "gpus_per_replica" {
  description = "nvidia.com/gpu requested by each replica."
  value       = var.model.tensor_parallel_size
}
