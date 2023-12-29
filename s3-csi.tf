locals {
  s3_csi_driver_policy    = length(var.s3_csi_driver_bucket_name) > 0
  s3_csi_driver_role_name = "${var.cluster_name}-s3-csi-driver-role"
}

module "eks_s3_csi_driver_irsa" {
  count = var.s3_csi_driver ? 1 : 0

  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.33.0"

  role_name = local.s3_csi_driver_role_name

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "kube-system:mountpoint-s3-csi-controller-sa",
      ]
    }
  }
  tags = var.tags
}

data "aws_iam_policy_document" "eks_s3_csi_driver" {
  count = local.s3_csi_driver_policy ? 1 : 0

  statement {
    sid = "MountpointFullBucketAccess"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:${local.aws_partition}:s3:::${var.s3_csi_driver_bucket_name}"
    ]
  }

  statement {
    sid = "MountpointFullObjectAccess"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:${local.aws_partition}:s3:::${var.s3_csi_driver_bucket_name}/*"
    ]
  }
}

resource "aws_iam_policy" "eks_s3_csi_driver" {
  count       = local.s3_csi_driver_policy ? 1 : 0
  name        = "AmazonEKS_S3_CSI_Policy-${var.cluster_name}"
  description = "Provides permissions to manage S3-backed volumes via the container storage interface driver"
  policy      = data.aws_iam_policy_document.eks_s3_csi_driver[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "s3_efs_csi_driver" {
  count      = local.s3_csi_driver_policy ? 1 : 0
  role       = module.eks_s3_csi_driver_irsa[0].iam_role_name
  policy_arn = aws_iam_policy.eks_s3_csi_driver[0].arn
  depends_on = [
    module.eks_s3_csi_driver_irsa[0]
  ]
}
