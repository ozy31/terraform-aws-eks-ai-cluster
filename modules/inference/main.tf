################################################################################
# vLLM model server
#
# Weights are read straight from S3 through a read-only Mountpoint volume, so
# a new replica does not copy the model onto the node first. KEDA scales on the
# vLLM request queue; Karpenter adds or removes GPU nodes underneath.
################################################################################

resource "helm_release" "this" {
  name             = var.name
  namespace        = var.namespace
  create_namespace = true
  chart            = "${path.module}/charts/vllm-service"

  # Model load can take several minutes on a cold node.
  timeout = 1200

  values = [yamlencode({
    image = {
      repository = var.image.repository
      tag        = var.image.tag
    }

    model = {
      bucket               = var.model_bucket.name
      region               = var.model_bucket.region
      s3Prefix             = trim(var.model.s3_prefix, "/")
      servedName           = var.model.served_name
      tensorParallelSize   = var.model.tensor_parallel_size
      maxModelLen          = var.model.max_model_len
      gpuMemoryUtilization = var.model.gpu_memory_utilization
      extraArgs            = var.model.extra_args
    }

    nodePool = var.node_pool

    resources = {
      cpu    = var.resources.cpu
      memory = var.resources.memory
      shm    = var.resources.shm
    }

    autoscaling = {
      enabled         = var.autoscaling.enabled
      minReplicas     = var.autoscaling.min_replicas
      maxReplicas     = var.autoscaling.max_replicas
      waitingPerPod   = var.autoscaling.waiting_per_pod
      prometheusUrl   = var.autoscaling.prometheus_url
      cooldownSeconds = var.autoscaling.cooldown_seconds
      wakeQuery       = var.autoscaling.wake_query != null ? var.autoscaling.wake_query : ""
    }

    serviceMonitor = {
      enabled      = var.enable_service_monitor
      releaseLabel = var.prometheus_release_label
    }
  })]
}
