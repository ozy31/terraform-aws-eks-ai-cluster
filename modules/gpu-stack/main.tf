locals {
  # Every component here only runs on GPU nodes: tolerate the pool taint and
  # pin to the label the gpu-nodepools module sets.
  gpu_tolerations = [
    { key = "nvidia.com/gpu", operator = "Exists", effect = "NoSchedule" },
    { key = "CriticalAddonsOnly", operator = "Exists" },
  ]

  gpu_affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [{
          matchExpressions = [{ key = "nvidia.com/gpu.present", operator = "In", values = ["true"] }]
        }]
      }
    }
  }

  time_slicing_config = yamlencode({
    version = "v1"
    sharing = {
      timeSlicing = {
        # Keep the resource name nvidia.com/gpu. Renaming to nvidia.com/gpu.shared
        # is safer in a static cluster, but Karpenter cannot provision nodes for a
        # resource it does not know about, so pods would stay Pending.
        renameByDefault = false
        resources = [{
          name     = "nvidia.com/gpu"
          replicas = var.time_slicing_replicas
        }]
      }
    }
  })
}

################################################################################
# NVIDIA device plugin: advertises nvidia.com/gpu to the kubelet
################################################################################

resource "helm_release" "nvidia_device_plugin" {
  count = var.install_device_plugin ? 1 : 0

  name             = "nvidia-device-plugin"
  namespace        = var.namespace
  create_namespace = true
  repository       = "https://nvidia.github.io/k8s-device-plugin"
  chart            = "nvidia-device-plugin"
  version          = var.chart_versions.nvidia_device_plugin

  values = [yamlencode(merge(
    {
      tolerations       = local.gpu_tolerations
      affinity          = local.gpu_affinity
      priorityClassName = "system-node-critical"
      # GPU Feature Discovery needs Node Feature Discovery; Karpenter already
      # labels nodes with instance GPU name, count and memory.
      gfd = { enabled = false }
      nfd = { enabled = false }
    },
    var.time_slicing_replicas > 1 ? {
      config = {
        default = "time-slicing"
        map     = { "time-slicing" = local.time_slicing_config }
      }
    } : {},
  ))]
}

################################################################################
# DCGM exporter: per-GPU utilization, memory, temperature, power and XID errors
################################################################################

resource "helm_release" "dcgm_exporter" {
  name             = "dcgm-exporter"
  namespace        = var.namespace
  create_namespace = true
  repository       = "https://nvidia.github.io/dcgm-exporter/helm-charts"
  chart            = "dcgm-exporter"
  version          = var.chart_versions.dcgm_exporter

  values = [yamlencode({
    tolerations       = local.gpu_tolerations
    affinity          = local.gpu_affinity
    priorityClassName = "system-node-critical"

    resources = {
      requests = { cpu = "100m", memory = "256Mi" }
      limits   = { memory = "512Mi" }
    }

    serviceMonitor = {
      enabled          = var.enable_service_monitor
      interval         = "15s"
      honorLabels      = true
      additionalLabels = { release = var.prometheus_release_label }
    }
  })]

  depends_on = [helm_release.nvidia_device_plugin]
}

################################################################################
# GPU alert rules
################################################################################

resource "helm_release" "gpu_alerts" {
  count = var.enable_service_monitor ? 1 : 0

  name      = "gpu-alerts"
  namespace = var.namespace
  chart     = "${path.module}/charts/gpu-alerts"

  values = [yamlencode({
    releaseLabel = var.prometheus_release_label
    thresholds = {
      temperatureCelsius  = var.alert_thresholds.temperature_celsius
      idleUtilizationPct  = var.alert_thresholds.idle_utilization_pct
      idleFor             = var.alert_thresholds.idle_for
      memoryUsedPct       = var.alert_thresholds.memory_used_pct
      memoryUsedPctFor    = var.alert_thresholds.memory_used_pct_for
      xidErrorLookback    = var.alert_thresholds.xid_error_lookback
      unhealthyForSeconds = var.alert_thresholds.unhealthy_for_seconds
    }
  })]

  depends_on = [helm_release.dcgm_exporter]
}
