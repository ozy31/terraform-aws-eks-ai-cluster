output "namespace" {
  description = "Namespace the GPU stack runs in."
  value       = var.namespace
}

output "gpus_per_physical_gpu" {
  description = "How many nvidia.com/gpu units each physical GPU is advertised as (time-slicing replicas)."
  value       = var.time_slicing_replicas
}

output "chart_versions" {
  description = "Deployed chart versions."
  value = {
    nvidia_device_plugin = var.install_device_plugin ? helm_release.nvidia_device_plugin[0].version : null
    dcgm_exporter        = helm_release.dcgm_exporter.version
  }
}
