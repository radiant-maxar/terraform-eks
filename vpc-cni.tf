# Authorize VPC CNI via IRSA.
module "eks_vpc_cni_irsa" {
  count   = var.vpc_cni ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.33.0"

  role_name = "${var.cluster_name}-vpc-cni-role"

  # XXX: Temporary
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

# Adapted from:
# https://github.com/aws/amazon-vpc-cni-k8s/blob/master/docs/iam-policy.md
#
# XXX: IPv6 is not supported
data "aws_iam_policy_document" "eks_vpc_cni" {
  count = var.vpc_cni ? 1 : 0

  statement {
    sid = "AllowRegionalReadActions"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeInstanceTypes",
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowTagCreation"
    actions = [
      "ec2:CreateTags"
    ]
    resources = [
      "arn:${local.aws_partition}:ec2:${local.aws_region}:*:network-interface/*",
    ]
  }

  # statement {
  #   sid = "AllowScopedCreateNetworkInterface"
  #   actions = [
  #     "ec2:CreateNetworkInterface"
  #   ]
  #   resources = [
  #     "arn:${local.aws_partition}:ec2:${local.aws_region}:*:network-interface/*",
  #   ]
  #   condition {
  #     test     = "StringEquals"
  #     variable = "aws:RequestTag/cluster.k8s.amazonaws.com/name"
  #     values   = [var.cluster_name]
  #   }
  # }

  # statement {
  #   sid = "AllowVPCCreateNetworkInterface"
  #   actions = [
  #     "ec2:CreateNetworkInterface"
  #   ]
  #   resources = [
  #     "arn:${local.aws_partition}:ec2:${local.aws_region}:*:subnet/*",
  #     "arn:${local.aws_partition}:ec2:${local.aws_region}:*:security-group/*",
  #   ]
  #   condition {
  #     test     = "ArnEquals"
  #     variable = "ec2:Vpc"
  #     values   = [var.vpc_id]
  #   }
  # }

  # statement {
  #   sid = "AllowScopedDeleteNetworkInterface"
  #   actions = [
  #     "ec2:DeleteNetworkInterface",
  #     "ec2:UnassignPrivateIpAddresses",
  #     "ec2:AssignPrivateIpAddresses",
  #     "ec2:AttachNetworkInterface",
  #     "ec2:DetachNetworkInterface",
  #     "ec2:ModifyNetworkInterfaceAttribute"
  #   ]
  #   resources = [
  #     "arn:${local.aws_partition}:ec2:${local.aws_region}:*:network-interface/*",
  #   ]
  #   condition {
  #     test     = "StringEquals"
  #     variable = "aws:ResourceTag/cluster.k8s.amazonaws.com/name"
  #     values   = [var.cluster_name]
  #   }
  # }

  # statement {
  #   sid = "AllowScopedAttachNetworkInterface"
  #   actions = [
  #     "ec2:AttachNetworkInterface",
  #     "ec2:DetachNetworkInterface",
  #     "ec2:ModifyNetworkInterfaceAttribute"
  #   ]
  #   resources = [
  #     "arn:${local.aws_partition}:ec2:${local.aws_region}:*:instance/*",
  #   ]
  #   condition {
  #     test     = "StringEquals"
  #     variable = "aws:ResourceTag/cluster.k8s.amazonaws.com/name"
  #     values   = [var.cluster_name]
  #   }
  # }

  # statement {
  #   sid = "AllowModifyNetworkInterfaceAttribute"
  #   actions = [
  #     "ec2:ModifyNetworkInterfaceAttribute"
  #   ]
  #   resources = [
  #     "arn:${local.aws_partition}:ec2:${local.aws_region}:*:security-group/*",
  #   ]
  # }
}

resource "aws_iam_policy" "eks_vpc_cni" {
  count       = var.vpc_cni ? 1 : 0
  name        = "AmazonEKS_CNI_Policy-${var.cluster_name}"
  description = "Provides the Amazon VPC CNI Plugin (amazon-vpc-cni-k8s) the permissions it requires to modify the IPv4/IPv6 address configuration on your EKS worker nodes"
  policy      = data.aws_iam_policy_document.eks_vpc_cni[0].json
  tags        = var.tags
}

# resource "aws_iam_role_policy_attachment" "eks_vpc_cni" {
#   count      = var.vpc_cni ? 1 : 0
#   role       = module.eks_vpc_cni_irsa[0].iam_role_name
#   policy_arn = aws_iam_policy.eks_vpc_cni[0].arn
#   depends_on = [
#     module.eks_vpc_cni_irsa[0]
#   ]
# }
