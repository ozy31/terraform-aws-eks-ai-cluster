################################################################################
# GPU EC2NodeClass + NodePools
#
# Shipped as a local chart instead of kubernetes_manifest so that `plan` does
# not need the Karpenter CRDs to exist yet (same pattern as the default pool in
# terraform-aws-eks-platform).
################################################################################

resource "helm_release" "gpu_nodepools" {
  name      = "gpu-nodepools"
  namespace = var.release_namespace
  chart     = "${path.module}/charts/gpu-nodepools"

  values = [yamlencode({
    clusterName = var.cluster_name
    nodeRole    = var.node_role_name
    tags        = var.tags

    nodeClass = {
      name              = "gpu"
      os                = var.node_os
      amiAliasVersion   = var.ami_alias_version
      rootVolumeSizeGiB = var.root_volume_size_gib
      instanceStoreRaid = var.use_instance_store
    }

    nodePools = {
      for name, p in var.node_pools : name => {
        instanceFamilies    = p.instance_families
        capacityTypes       = p.capacity_types
        maxGpusPerNode      = tostring(p.max_gpus_per_node + 1)
        gpuLimit            = tostring(p.gpu_limit)
        weight              = p.weight
        consolidationPolicy = p.consolidation_policy
        consolidateAfter    = p.consolidate_after
        expireAfter         = p.expire_after
        disruptionNodes     = p.disruption_nodes
      }
    }
  })]
}
