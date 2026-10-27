variable "region" {
  description = "AWS region of the cluster."
  type        = string
  default     = "eu-west-1"
}

variable "cluster_name" {
  description = "Existing EKS cluster with Karpenter, KEDA and kube-prometheus-stack installed."
  type        = string
  default     = "prod-euw1"
}

variable "karpenter_node_role_name" {
  description = "Node IAM role created by the karpenter module of terraform-aws-eks-platform."
  type        = string
  default     = "prod-euw1-karpenter-node"
}
