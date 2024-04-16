## EFS CSI Storage Driver

locals {
  efs_access_point_arns = [
    "arn:${local.aws_partition}:elasticfilesystem:${local.aws_region}:${local.aws_account_id}:access-point/*"
  ]
}

resource "aws_efs_file_system" "eks_efs" {
  count          = var.efs_csi_driver ? 1 : 0
  creation_token = "${var.cluster_name}-efs"
  encrypted      = true
  kms_key_id     = var.kms_manage ? aws_kms_key.this[0].arn : module.eks.kms_key_arn
  tags           = var.tags
}

resource "aws_efs_mount_target" "eks_efs_private" {
  count           = var.efs_csi_driver ? length(var.private_subnets) : 0
  file_system_id  = aws_efs_file_system.eks_efs[0].id
  subnet_id       = var.private_subnets[count.index]
  security_groups = [module.eks.cluster_primary_security_group_id]
}

# Allow PVCs backed by EFS
module "eks_efs_csi_driver_irsa" {
  count   = var.efs_csi_driver ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39.0"

  role_name = "${var.cluster_name}-efs-csi-driver-role"

  oidc_providers = {
    controller = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "${var.efs_csi_driver_namespace}:efs-csi-controller-sa",
      ]
    }
    node = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "${var.efs_csi_driver_namespace}:efs-csi-node-sa",
      ]
    }
  }
  tags = var.tags
}

data "aws_iam_policy_document" "eks_efs_csi_driver" {
  count = var.efs_csi_driver ? 1 : 0

  statement {
    sid       = "AllowDescribeAvailabilityZones"
    actions   = ["ec2:DescribeAvailabilityZones"]
    resources = ["*"] # tfsec:ignore:aws-iam-no-policy-wildcards
  }

  statement {
    sid = "AllowDescribeFileSystems"
    actions = [
      "elasticfilesystem:DescribeAccessPoints",
      "elasticfilesystem:DescribeFileSystems",
      "elasticfilesystem:DescribeMountTargets"
    ]
    resources = flatten([
      aws_efs_file_system.eks_efs[*].arn,
      local.efs_access_point_arns,
    ])
  }

  statement {
    actions = [
      "elasticfilesystem:CreateAccessPoint",
      "elasticfilesystem:TagResource",
    ]
    resources = aws_efs_file_system.eks_efs[*].arn

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/efs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    sid       = "AllowDeleteAccessPoint"
    actions   = ["elasticfilesystem:DeleteAccessPoint"]
    resources = local.efs_access_point_arns

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/efs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    sid = "ClientReadWrite"
    actions = [
      "elasticfilesystem:ClientRootAccess",
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:ClientMount",
    ]
    resources = aws_efs_file_system.eks_efs[*].arn

    condition {
      test     = "Bool"
      variable = "elasticfilesystem:AccessedViaMountTarget"
      values   = ["true"]
    }
  }
}

resource "aws_iam_policy" "eks_efs_csi_driver" {
  count       = var.efs_csi_driver ? 1 : 0
  name        = "AmazonEKS_EFS_CSI_Policy-${var.cluster_name}"
  description = "Provides permissions to manage EFS volumes via the container storage interface driver"
  policy      = data.aws_iam_policy_document.eks_efs_csi_driver[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_efs_csi_driver" {
  count      = var.efs_csi_driver ? 1 : 0
  role       = module.eks_efs_csi_driver_irsa[0].iam_role_name
  policy_arn = aws_iam_policy.eks_efs_csi_driver[0].arn
  depends_on = [
    module.eks_efs_csi_driver_irsa[0]
  ]
}

resource "helm_release" "aws_efs_csi_driver" {
  count            = var.efs_csi_driver && var.efs_csi_driver_helm ? 1 : 0
  chart            = try(var.efs_csi_driver_options.chart, "aws-efs-csi-driver")
  create_namespace = var.efs_csi_driver_namespace == "kube-system" ? false : true
  max_history      = try(var.efs_csi_driver_options.max_history, 10)
  name             = try(var.efs_csi_driver_options.name, "aws-efs-csi-driver")
  namespace        = var.efs_csi_driver_namespace
  repository       = try(var.efs_csi_driver_options.repository, "https://kubernetes-sigs.github.io/aws-efs-csi-driver")
  timeout          = try(var.efs_csi_driver_options.timeout, 600)
  version          = var.efs_csi_driver_version
  wait             = var.efs_csi_driver_wait

  atomic                     = try(var.efs_csi_driver_options.atomic, null)
  cleanup_on_fail            = try(var.efs_csi_driver_options.cleanup_on_fail, null)
  dependency_update          = try(var.efs_csi_driver_options.dependency_update, null)
  devel                      = try(var.efs_csi_driver_options.devel, null)
  disable_openapi_validation = try(var.efs_csi_driver_options.disable_openapi_validation, null)
  disable_webhooks           = try(var.efs_csi_driver_options.disable_webhooks, null)
  force_update               = try(var.efs_csi_driver_options.force_update, null)
  lint                       = try(var.efs_csi_driver_options.lint, null)
  recreate_pods              = try(var.efs_csi_driver_options.recreate_pods, null)
  render_subchart_notes      = try(var.efs_csi_driver_options.render_subchart_notes, null)
  replace                    = try(var.efs_csi_driver_options.replace, null)
  repository_key_file        = try(var.efs_csi_driver_options.repository_key_file, null)
  repository_cert_file       = try(var.efs_csi_driver_options.repository_cert_file, null)
  repository_ca_file         = try(var.efs_csi_driver_options.repository_ca_file, null)
  repository_username        = try(var.efs_csi_driver_options.repository_username, null)
  repository_password        = try(var.efs_csi_driver_options.repository_password, null)
  reset_values               = try(var.efs_csi_driver_options.reset_values, null)
  reuse_values               = try(var.efs_csi_driver_options.reuse_values, null)
  skip_crds                  = try(var.efs_csi_driver_options.skip_crds, null)
  wait_for_jobs              = try(var.efs_csi_driver_options.wait_for_jobs, null)

  values = [
    yamlencode({
      controller = {
        tags = local.tags_noname
      }
    }),
    yamlencode(var.efs_csi_driver_values),
  ]

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks_efs_csi_driver_irsa[0].iam_role_arn
  }

  set {
    name  = "image.repository"
    value = "${var.csi_ecr_repository_id}.dkr.ecr.${local.aws_region}.amazonaws.com/eks/aws-efs-csi-driver"
  }

  set {
    name  = "node.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks_efs_csi_driver_irsa[0].iam_role_arn
  }

  depends_on = [
    module.eks_efs_csi_driver_irsa[0],
    module.eks,
  ]
}

resource "kubernetes_storage_class" "eks_efs_storage_class" {
  count = var.efs_csi_driver ? 1 : 0

  metadata {
    annotations = {}
    name        = "efs-sc"
    labels      = {}
  }

  mount_options = var.efs_storage_class_mount_options
  parameters = merge(
    var.efs_storage_class_parameters,
    { "fileSystemId" = aws_efs_file_system.eks_efs[0].id }
  )
  storage_provisioner = "efs.csi.aws.com"

  depends_on = [
    helm_release.aws_efs_csi_driver[0],
  ]
}
