variable "name" {
  description = "Name of the model deployment; used for the release, Deployment, Service and ScaledObject."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]{0,40}[a-z0-9])?$", var.name))
    error_message = "name must be a DNS-1123 label of at most 42 characters."
  }
}

variable "namespace" {
  description = "Namespace to deploy into. Created if missing."
  type        = string
  default     = "inference"
}

variable "model" {
  description = <<-EOT
    The model to serve.

    s3_prefix              Prefix inside the model bucket that holds the Hugging Face-format weights (config.json, *.safetensors, tokenizer).
    served_name            Name clients pass in the OpenAI-compatible API ("model": "...").
    tensor_parallel_size   GPUs per replica. The model is sharded across them; it is also the nvidia.com/gpu request.
    max_model_len          Maximum context length. Lower values leave more GPU memory for KV cache and concurrency.
    gpu_memory_utilization Share of GPU memory vLLM may claim for weights + KV cache.
    extra_args             Additional vLLM CLI flags (for example --quantization fp8, --enable-prefix-caching).
  EOT
  type = object({
    s3_prefix              = string
    served_name            = string
    tensor_parallel_size   = optional(number, 1)
    max_model_len          = optional(number, 8192)
    gpu_memory_utilization = optional(number, 0.90)
    extra_args             = optional(list(string), [])
  })

  validation {
    condition     = contains([1, 2, 4, 8], var.model.tensor_parallel_size)
    error_message = "tensor_parallel_size must be 1, 2, 4 or 8."
  }

  validation {
    condition     = var.model.gpu_memory_utilization > 0.5 && var.model.gpu_memory_utilization <= 0.95
    error_message = "gpu_memory_utilization must be between 0.5 and 0.95."
  }
}

variable "model_bucket" {
  description = "Model bucket name and region (outputs of the model-store module)."
  type = object({
    name   = string
    region = string
  })
}

variable "image" {
  description = "vLLM OpenAI-compatible server image."
  type = object({
    repository = optional(string, "vllm/vllm-openai")
    tag        = optional(string, "v0.32.0")
  })
  default = {}
}

variable "node_pool" {
  description = "GPU NodePool (ai.platform/pool label) the replicas run on."
  type        = string
  default     = "inference"
}

variable "resources" {
  description = "CPU and memory for each replica. GPUs come from model.tensor_parallel_size."
  type = object({
    cpu    = optional(string, "4")
    memory = optional(string, "32Gi")
    shm    = optional(string, "8Gi")
  })
  default = {}
}

variable "autoscaling" {
  description = <<-EOT
    KEDA scaling on vLLM queue depth.

    min_replicas      0 enables scale-to-zero. Cheapest, but the first request after idle waits for a
                      GPU node and a model load (minutes). Keep >= 1 for latency-sensitive traffic.
    max_replicas      Upper bound; the NodePool gpu_limit is the second guardrail.
    waiting_per_pod   Target number of queued requests per replica (vllm:num_requests_waiting).
    prometheus_url    In-cluster Prometheus the ScaledObject queries.
    cooldown_seconds  Idle time before scaling to zero.
    wake_query        PromQL returning > 0 when requests arrive upstream (for example a gateway
                      request-rate counter). Required for min_replicas = 0: a scaled-to-zero vLLM
                      exports no queue metric, so nothing else can wake it.
  EOT
  type = object({
    enabled          = optional(bool, true)
    min_replicas     = optional(number, 1)
    max_replicas     = optional(number, 4)
    waiting_per_pod  = optional(number, 5)
    prometheus_url   = optional(string, "http://kube-prometheus-stack-prometheus.monitoring.svc:9090")
    cooldown_seconds = optional(number, 900)
    wake_query       = optional(string)
  })
  default = {}

  validation {
    condition     = var.autoscaling.min_replicas >= 0 && var.autoscaling.max_replicas >= max(var.autoscaling.min_replicas, 1)
    error_message = "autoscaling.max_replicas must be >= max(min_replicas, 1)."
  }

  validation {
    condition     = var.autoscaling.min_replicas > 0 || var.autoscaling.wake_query != null
    error_message = "autoscaling.min_replicas = 0 needs autoscaling.wake_query, otherwise nothing scales the model back up."
  }
}

variable "enable_service_monitor" {
  description = "Create a ServiceMonitor for the vLLM /metrics endpoint (needed for KEDA scaling and dashboards)."
  type        = bool
  default     = true
}

variable "prometheus_release_label" {
  description = "Value of the `release` label the Prometheus Operator selects ServiceMonitors by."
  type        = string
  default     = "kube-prometheus-stack"
}
