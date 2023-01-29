provider "helm" {
  kubernetes {
    host                   = module.eks_cluster.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster.eks_cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster-auth.token
  }
}

provider "kubernetes" {
  host                   = module.eks_cluster.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.eks_cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster-auth.token
}

data "aws_eks_cluster_auth" "cluster-auth" {
  depends_on = [module.eks_cluster.kubernetes_config_map_id, module.eks_cluster]
  name       = module.eks_cluster.eks_cluster_id
}