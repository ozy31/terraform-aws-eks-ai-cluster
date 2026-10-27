variable "namespace" {
  description = "Namespace for the NVIDIA device plugin, DCGM exporter and GPU alert rules."
  type        = string
  default     = "gpu-system"
}

variable "chart_versions" {
  description = "Pinned upstream chart versions."
  type = object({
    nvidia_device_plugin = optional(string, "0.20.1")
    dcgm_exporter        = optional(string, "4.8.4")
  })
  default = {}
}

variable "install_device_plugin" {
  description = "Install the NVIDIA device plugin. Set false on Bottlerocket, whose -nvidia variant ships the plugin in the host image."
  type        = bool
  default     = true
}

variable "time_slicing_replicas" {
  description = "Advertise each physical GPU as this many nvidia.com/gpu resources (time-slicing). 1 disables sharing. Useful for dev, small models and notebooks; there is no memory isolation between sharers."
  type        = number
  default     = 1

  validation {
    condition     = var.time_slicing_replicas >= 1 && var.time_slicing_replicas <= 16
    error_message = "time_slicing_replicas must be between 1 and 16."
  }
}

variable "enable_service_monitor" {
  description = "Create a ServiceMonitor for DCGM exporter and the GPU PrometheusRule. Requires the Prometheus Operator CRDs (kube-prometheus-stack)."
  type        = bool
  default     = true
}

variable "prometheus_release_label" {
  description = "Value of the `release` label the Prometheus Operator selects ServiceMonitors and rules by."
  type        = string
  default     = "kube-prometheus-stack"
}

variable "alert_thresholds" {
  description = "Thresholds for the GPU alert rules."
  type = object({
    temperature_celsius   = optional(number, 85)
    idle_utilization_pct  = optional(number, 5)
    idle_for              = optional(string, "2h")
    memory_used_pct       = optional(number, 95)
    memory_used_pct_for   = optional(string, "15m")
    xid_error_lookback    = optional(string, "10m")
    unhealthy_for_seconds = optional(number, 300)
  })
  default = {}
}
