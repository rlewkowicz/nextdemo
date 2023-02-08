module "eks_cluster" {
  source  = "cloudposse/eks-cluster/aws"
  version = "0.45.0"

  namespace = var.namespace
  stage     = var.stage
  name      = var.name

  region                = var.region
  create_security_group = true

  vpc_id                = var.vpc_id
  subnet_ids            = var.subnet_ids
  kubernetes_version    = "1.23"
  oidc_provider_enabled = true

  enabled_cluster_log_types = []

  wait_for_cluster_command = "curl --silent --fail --retry 90 --retry-delay 5 --retry-connrefused --insecure --output /dev/null $ENDPOINT/healthz"
}


module "eks_node_group" {
  source  = "cloudposse/eks-node-group/aws"
  version = "0.28.0"

  namespace = var.namespace
  stage     = var.stage
  name      = var.name

  instance_types     = ["t3a.large"]
  subnet_ids         = var.subnet_ids
  cluster_name       = module.eks_cluster.eks_cluster_id
  desired_size       = var.size
  min_size           = var.size
  max_size           = var.size
  kubernetes_version = ["1.23"]
  resources_to_tag   = ["instance", "volume", "network-interface"]
  label_key_case     = "title"
  capacity_type      = "SPOT"

  associated_security_group_ids = [module.eks_cluster.security_group_id]

  depends_on = [module.eks_cluster.kubernetes_config_map_id]

  create_before_destroy = true

  node_group_terraform_timeouts = [{
    create = "40m"
    update = null
    delete = "20m"
  }]
}


resource "helm_release" "cert_manager" {
  depends_on = [module.eks_node_group]

  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.7.1"
  namespace        = "cert-manager"
  create_namespace = true


  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "helm_release" "nginx_ingress" {
  depends_on = [helm_release.cert_manager, module.eks_node_group]

  name             = "nginx-ingress"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "./helm/nginx-ingress-controller"
  version          = "9.3.26"
  namespace        = "nginx"
  create_namespace = true
  verify           = false

  set {
    name  = "ingressClassResource.default"
    value = "true"
  }

  set {
    name  = "publishService.enabled"
    value = "true"
  }

  values = [
    <<EOF
config: 
  hsts: "false"
EOF
  ]
}

resource "helm_release" "external_dns_helm" {
  depends_on = [aws_iam_role.external_dns_controller_role, module.eks_node_group]

  name             = "external-dns"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "./helm/external-dns"
  version          = "6.13.1"
  namespace        = "external-dns"
  create_namespace = true
  verify           = false
  force_update     = true

  set {
    name  = "serviceAccount.name"
    value = "external-dns-controller"
  }

  set {
    name  = "sources"
    value = "{ingress}"
  }

  values = [
    <<EOF
serviceAccount: 
  annotations: 
    eks.amazonaws.com/role-arn: ${aws_iam_role.external_dns_controller_role.arn}
EOF
  ]
}

resource "helm_release" "redis" {
  depends_on = [module.eks_node_group]

  name             = "redis"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "./helm/redis"
  version          = "17.6.0"
  namespace        = "redis"
  create_namespace = true
  verify           = false
  force_update     = true
}

resource "helm_release" "argo-cd" {
  depends_on = [helm_release.nginx_ingress, helm_release.redis, module.eks_node_group]

  name             = "argo-cd"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "./helm/argo-cd"
  version          = "4.4.4"
  namespace        = "argo-cd"
  create_namespace = true
  verify           = false
  force_update     = true
}

resource "helm_release" "crossplane" {
  depends_on = [module.eks_node_group]

  name             = "crossplane"
  repository       = "https://charts.crossplane.io/stable"
  chart            = "./helm/crossplane"
  version          = "1.11.0"
  namespace        = "crossplane"
  create_namespace = true
  verify           = false
  force_update     = true
}

data "aws_caller_identity" "current" {}

resource "kubernetes_manifest" "crossplane_controller_config" {

  depends_on = [helm_release.crossplane, module.eks_node_group, aws_iam_role.crossplane]

  manifest = {

    apiVersion = "pkg.crossplane.io/v1alpha1"
    kind       = "ControllerConfig"

    metadata = {
      name = "aws-config"
      annotations = {
        "eks.amazonaws.com/role-arn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.crossplane.name}"
      }
    }

    spec = {
      podSecurityContext = { fsGroup : 2000 }
    }
  }
}
