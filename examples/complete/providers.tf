provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

# The cluster already exists (built by terraform-aws-eks-platform); only read it.
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

# Short-lived tokens via the AWS CLI; nothing long-lived ends up in state.
provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
    }
  }
}
