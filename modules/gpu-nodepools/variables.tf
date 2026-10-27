variable "cluster_name" {
  description = "EKS cluster name. Subnets and security groups are discovered through the karpenter.sh/discovery tag."
  type        = string
}

variable "node_role_name" {
  description = "IAM role name for Karpenter-provisioned nodes (node_iam_role_name output of the karpenter module)."
  type        = string
}

variable "node_os" {
  description = "AMI family alias. al2023 resolves to the EKS-optimized NVIDIA AMI on GPU instance types; bottlerocket resolves to the -nvidia variant."
  type        = string
  default     = "al2023"

  validation {
    condition     = contains(["al2023", "bottlerocket"], var.node_os)
    error_message = "node_os must be al2023 or bottlerocket."
  }
}

variable "ami_alias_version" {
  description = "AMI alias version. Pin it (for example v20261015) in production so node images only change through a reviewed PR and drift."
  type        = string
  default     = "latest"
}

variable "root_volume_size_gib" {
  description = "EBS root (al2023) or data (bottlerocket) volume size. Inference images are large; 200 GiB keeps several cached."
  type        = number
  default     = 200
}

variable "use_instance_store" {
  description = "Stripe local NVMe instance store into RAID0 and use it for kubelet/containerd storage. Fast model and image cache on g5/g6/p4/p5."
  type        = bool
  default     = true
}

variable "node_pools" {
  description = <<-EOT
    GPU NodePools keyed by name. Every pool is tainted nvidia.com/gpu=true:NoSchedule and labelled
    ai.platform/pool=<name>, so only workloads that ask for a pool land on it.

    instance_families    EC2 families Karpenter may pick from (g6, g6e, g5, p4d, p5, ...).
    capacity_types       spot and/or on-demand. Karpenter prefers spot when both are allowed.
    max_gpus_per_node    Upper bound on GPUs per instance; keeps the pool from jumping to 8-GPU boxes.
    gpu_limit            Total GPUs the pool may provision. The real cost guardrail.
    weight               Higher weight is tried first when several pools match a pod.
    consolidation_policy WhenEmpty for jobs that must not be interrupted, WhenEmptyOrUnderutilized for stateless serving.
    consolidate_after    How long a node has to stay empty/underutilized before it is removed.
    expire_after         Maximum node lifetime before forced rotation.
    disruption_nodes     How many nodes may be disrupted at once (number or percentage).
  EOT
  type = map(object({
    instance_families    = list(string)
    capacity_types       = optional(list(string), ["spot", "on-demand"])
    max_gpus_per_node    = optional(number, 1)
    gpu_limit            = number
    weight               = optional(number, 10)
    consolidation_policy = optional(string, "WhenEmptyOrUnderutilized")
    consolidate_after    = optional(string, "10m")
    expire_after         = optional(string, "720h")
    disruption_nodes     = optional(string, "1")
  }))

  default = {
    inference = {
      instance_families = ["g6", "g6e", "g5"]
      max_gpus_per_node = 4
      gpu_limit         = 16
      weight            = 50
    }
    training = {
      instance_families    = ["p5", "p4d", "g6e"]
      capacity_types       = ["on-demand"]
      max_gpus_per_node    = 8
      gpu_limit            = 16
      consolidation_policy = "WhenEmpty"
      consolidate_after    = "5m"
      disruption_nodes     = "0"
    }
  }

  validation {
    condition = alltrue([
      for p in values(var.node_pools) : contains(["WhenEmpty", "WhenEmptyOrUnderutilized"], p.consolidation_policy)
    ])
    error_message = "consolidation_policy must be WhenEmpty or WhenEmptyOrUnderutilized."
  }

  validation {
    condition = alltrue([
      for p in values(var.node_pools) : length(setsubtract(p.capacity_types, ["spot", "on-demand"])) == 0
    ])
    error_message = "capacity_types may only contain spot and on-demand."
  }
}

variable "release_namespace" {
  description = "Namespace that holds the Helm release metadata. The NodePools and EC2NodeClass themselves are cluster-scoped."
  type        = string
  default     = "karpenter"
}

variable "tags" {
  description = "Tags applied to every instance, volume and network interface Karpenter launches from these pools."
  type        = map(string)
  default     = {}
}
