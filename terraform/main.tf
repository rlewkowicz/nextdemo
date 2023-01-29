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
  kubernetes_version    = "1.22"
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

  instance_types     = ["t3a.small"]
  subnet_ids         = var.subnet_ids
  cluster_name       = module.eks_cluster.eks_cluster_id
  desired_size       = var.size
  min_size           = var.size
  max_size           = var.size
  kubernetes_version = ["1.22"]
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
  verify = false

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
  verify = false
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

