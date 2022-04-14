data "aws_caller_identity" "default" {}
data "aws_region" "default" {}

locals {
  aws_account_id = data.aws_caller_identity.default.account_id
  aws_region     = data.aws_region.default.name
  aws_auth_file  = "${path.root}/aws-auth-${var.cluster_name}.yaml"

  # AWS Load Balancer Controller needs these additional security groups to work.
  load_balancer_security_group_rules = {
    egress_cluster_9443 = {
      description                   = "Node groups to cluster webooks"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      type                          = "egress"
      source_cluster_security_group = true
    }
    ingress_cluster_9443 = {
      description                   = "Cluster webooks to node grups"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }
}

resource "aws_kms_key" "this" {
  deletion_window_in_days = 10
  description             = "KMS Key for EKS Secrets"
  enable_key_rotation     = true
  tags                    = var.tags
}

module "eks_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.9.0"

  ingress_cidr_blocks = [var.vpc_cidr]
  name                = var.cluster_name
  vpc_id              = var.vpc_id

  tags = var.tags
}

resource "aws_security_group" "eks_efs_sg" {
  name        = "${var.cluster_name}-efs-sg"
  description = "Security group for EFS clients in EKS VPC"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = var.tags
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.20.1"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = module.eks_vpc_cni_irsa.iam_role_arn
    }
  }

  cluster_encryption_config = [{
    provider_key_arn = aws_kms_key.this.arn
    resources        = ["secrets"]
  }]

  enable_irsa = true
  subnet_ids  = concat(var.public_subnets, var.private_subnets)
  vpc_id      = var.vpc_id

  node_security_group_additional_rules = merge(local.load_balancer_security_group_rules, var.node_security_group_additional_rules)

  eks_managed_node_group_defaults = {
    ami_type                   = var.default_ami_type
    capacity_type              = var.default_capacity_type
    desired_size               = var.default_desired_size
    ebs_optimized              = true
    iam_role_attach_cni_policy = var.iam_role_attach_cni_policy
    max_size                   = var.default_max_size
    min_size                   = var.default_min_size
    vpc_security_group_ids = [
      aws_security_group.eks_efs_sg.id,
      module.eks_security_group.security_group_id,
    ]
  }
  eks_managed_node_groups = var.eks_managed_node_groups

  tags = var.tags
}

# Add EKS to default kubeconfig and set context for it.
resource "null_resource" "eks_kubeconfig" {
  provisioner "local-exec" {
    command = "aws --region ${local.aws_region} eks update-kubeconfig --name ${var.cluster_name} --alias ${var.cluster_name}"
  }
  depends_on = [
    module.eks,
  ]
}

# Configure aws-auth to allow any addition roles for system:masters access.
resource "local_file" "eks_aws_auth_configmap" {
  content = templatefile("${path.module}/templates/aws_auth_configmap.tpl", {
    aws_account_id          = local.aws_account_id
    aws_auth_configmap_yaml = module.eks.aws_auth_configmap_yaml
    system_masters_roles    = var.system_masters_roles
  })
  filename        = local.aws_auth_file
  file_permission = "0644"

  depends_on = [
    module.eks,
  ]
}

resource "null_resource" "eks_poweruser_auth" {
  provisioner "local-exec" {
    command = "kubectl --context='${var.cluster_name}' patch configmap/aws-auth -n kube-system --patch-file ${local.aws_auth_file}"
  }
  triggers = {
    auth_configmap = local_file.eks_aws_auth_configmap.content
  }
  depends_on = [
    local_file.eks_aws_auth_configmap,
    null_resource.eks_kubeconfig,
  ]
}

# Authorize Amazon Load Balancer Controller
module "eks_lb_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "4.18.0"

  role_name                              = "${var.cluster_name}-lb-role"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = var.tags
}

# Authorize VPC CNI via IRSA.
module "eks_vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "4.18.0"

  role_name             = "${var.cluster_name}-vpc-cni-role"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = var.tags
}

# Allow PVCs backed by EBS
module "eks_ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "4.18.0"

  role_name             = "${var.cluster_name}-ebs-csi-role"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}

# Allow PVCs backed by EFS
module "eks_efs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "4.18.0"

  role_name = "${var.cluster_name}-efs-csi-role"
  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "kube-system:efs-csi-controller-sa",
        "kube-system:efs-csi-node-sa",
      ]
    }
  }
  tags = var.tags
}

data "aws_iam_policy_document" "eks_efs_csi" {
  statement {
    actions = [
      "elasticfilesystem:DescribeAccessPoints",
      "elasticfilesystem:DescribeFileSystems",
      "elasticfilesystem:DescribeMountTargets",
      "ec2:DescribeAvailabilityZones",
    ]
    resources = ["*"]
  }

  statement {
    actions   = ["elasticfilesystem:CreateAccessPoint"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/efs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    actions   = ["elasticfilesystem:DeleteAccessPoint"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/efs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }
}

resource "aws_iam_policy" "eks_efs_csi" {
  name        = "AmazonEKS_EFS_CSI_Driver_Policy-${var.cluster_name}"
  description = "Provides permissions to manage EFS the container storage interface driver"
  policy      = data.aws_iam_policy_document.eks_efs_csi.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_efs_csi" {
  role       = "${var.cluster_name}-efs-csi-role"
  policy_arn = aws_iam_policy.eks_efs_csi.arn
  depends_on = [
    module.eks_efs_csi_irsa
  ]
}

resource "aws_efs_file_system" "eks_efs" {
  creation_token = "${var.cluster_name}-efs"
  encrypted      = true
  kms_key_id     = aws_kms_key.this.key_id
  tags           = var.tags
}

resource "aws_efs_mount_target" "eks_efs_private" {
  count           = length(var.private_subnets)
  file_system_id  = aws_efs_file_system.eks_efs.id
  subnet_id       = var.private_subnets[count.index]
  security_groups = [aws_security_group.eks_efs_sg.id]
}


## Kubernetes-level configuration

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--region", local.aws_region, "--cluster-name", module.eks.cluster_id]
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws"
    args        = ["eks", "get-token", "--region", local.aws_region, "--cluster-name", module.eks.cluster_id]
  }
}

## AWS Load Balancer Controller
resource "kubernetes_service_account" "eks_lb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/component" = "controller"
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn"               = "arn:aws:iam::${local.aws_account_id}:role/${var.cluster_name}-lb-role"
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }

  depends_on = [
    module.eks,
  ]
}

resource "helm_release" "aws_lb_controller" {
  name      = "aws-load-balancer-controller"
  chart     = "https://aws.github.io/eks-charts/aws-load-balancer-controller-${var.lb_controller_version}.tgz"
  namespace = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "region"
    value = local.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  dynamic "set" {
    for_each = var.tags
    content {
      name  = "defaultTags.${set.key}"
      value = set.value
    }
  }

  depends_on = [
    kubernetes_service_account.eks_lb_controller
  ]
}

# XXX: Unless this webhook is deleted, the load balancer controller won't create
# ALBs dynamically because AWS requires use of their private CA via cert-manager:
#   https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/install/v2_2_4_full.yaml#L840
resource "null_resource" "eks_delete_lb_validating_webook" {
  provisioner "local-exec" {
    command = "kubectl --context='${var.cluster_name}' delete ValidatingWebhookConfiguration/aws-load-balancer-webhook"
  }

  depends_on = [
    helm_release.aws_lb_controller
  ]
}

## EBS CSI Storage

# Don't want gp2 storageclass set as default.
resource "null_resource" "eks_disable_gp2" {
  provisioner "local-exec" {
    command = "kubectl --context='${var.cluster_name}' patch storageclass gp2 -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"false\"}}}'"
  }
  depends_on = [
    module.eks,
  ]
}

resource "kubernetes_service_account" "eks_ebs_controller_sa" {
  metadata {
    name      = "ebs-csi-controller-sa"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = "aws-ebs-csi-driver"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::${local.aws_account_id}:role/${var.cluster_name}-ebs-csi-role"
    }
  }
  depends_on = [
    module.eks,
  ]
}

resource "helm_release" "aws_ebs_csi_driver" {
  name      = "aws-ebs-csi-driver"
  chart     = "https://github.com/kubernetes-sigs/aws-ebs-csi-driver/releases/download/helm-chart-aws-ebs-csi-driver-${var.ebs_csi_driver_version}/aws-ebs-csi-driver-${var.ebs_csi_driver_version}.tgz"
  namespace = "kube-system"

  set {
    name  = "image.repository"
    value = "${var.csi_ecr_repository_id}.dkr.ecr.${local.aws_region}.amazonaws.com/eks/aws-ebs-csi-driver"
  }

  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "ebs-csi-controller-sa"
  }

  dynamic "set" {
    for_each = var.tags
    content {
      name  = "controller.extraVolumeTags.${set.key}"
      value = set.value
    }
  }

  depends_on = [
    kubernetes_service_account.eks_ebs_controller_sa,
  ]
}

# Make EBS CSI with gp3 default storage driver
resource "kubernetes_storage_class" "eks_ebs_storage_class" {
  metadata {
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
    labels = {}
    name   = "ebs-sc"
  }

  mount_options       = []
  parameters          = {}
  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"

  depends_on = [
    helm_release.aws_ebs_csi_driver,
  ]
}

## EFS CSI Storage
resource "kubernetes_service_account" "eks_efs_controller_sa" {
  metadata {
    name      = "efs-csi-controller-sa"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = "aws-efs-csi-driver"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::${local.aws_account_id}:role/${var.cluster_name}-efs-csi-role"
    }
  }
  depends_on = [
    module.eks,
  ]
}

resource "kubernetes_service_account" "eks_efs_node_sa" {
  metadata {
    name      = "efs-csi-node-sa"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = "aws-efs-csi-driver"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::${local.aws_account_id}:role/${var.cluster_name}-efs-csi-role"
    }
  }
  depends_on = [
    module.eks,
  ]
}

resource "helm_release" "aws_efs_csi_driver" {
  name      = "aws-efs-csi-driver"
  chart     = "https://github.com/kubernetes-sigs/aws-efs-csi-driver/releases/download/helm-chart-aws-efs-csi-driver-${var.efs_csi_driver_version}/aws-efs-csi-driver-${var.efs_csi_driver_version}.tgz"
  namespace = "kube-system"

  set {
    name  = "image.repository"
    value = "${var.csi_ecr_repository_id}.dkr.ecr.${local.aws_region}.amazonaws.com/eks/aws-efs-csi-driver"
  }

  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "efs-csi-controller-sa"
  }

  set {
    name  = "node.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "node.serviceAccount.name"
    value = "efs-csi-node-sa"
  }

  dynamic "set" {
    for_each = var.tags
    content {
      name  = "controller.tags.${set.key}"
      value = set.value
    }
  }

  depends_on = [
    kubernetes_service_account.eks_efs_controller_sa,
    kubernetes_service_account.eks_efs_node_sa,
  ]
}

resource "kubernetes_storage_class" "eks_efs_storage_class" {
  metadata {
    annotations = {}
    name        = "efs-sc"
    labels      = {}
  }

  mount_options = []
  parameters = {
    "provisioningMode" = "efs-ap"
    "fileSystemId"     = aws_efs_file_system.eks_efs.id
    "directoryPerms"   = "755"
    "uid"              = "0"
    "gid"              = "0"
  }
  storage_provisioner = "efs.csi.aws.com"

  depends_on = [
    helm_release.aws_efs_csi_driver,
  ]
}

## Nvidia Device Plugin for GPU support
resource "null_resource" "eks_nvidia_device_plugin" {
  count = var.nvidia_device_plugin ? 1 : 0
  provisioner "local-exec" {
    command = "kubectl --context='${var.cluster_name}' apply --filename='https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v${var.nvidia_device_plugin_version}/nvidia-device-plugin.yml'"
  }
  depends_on = [
    module.eks,
  ]
}
