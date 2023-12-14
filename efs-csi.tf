## EFS CSI Storage Driver
resource "aws_security_group" "eks_efs_sg" {
  name        = "${var.cluster_name}-efs-sg"
  description = "Security group for EFS clients in EKS VPC"
  vpc_id      = var.vpc_id

  ingress {
    description = "Ingress NFS traffic for EFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = var.tags
}

# Allow PVCs backed by EFS
module "eks_efs_csi_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.32.1"

  role_name             = "${var.cluster_name}-efs-csi-controller-role"
  attach_efs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "kube-system:efs-csi-controller-sa",
      ]
    }
  }
  tags = var.tags
}

module "eks_efs_csi_node_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.32.1"

  role_name = "${var.cluster_name}-efs-csi-node-role"
  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "kube-system:efs-csi-node-sa",
      ]
    }
  }
  tags = var.tags
}

data "aws_iam_policy_document" "eks_efs_csi_node" {
  statement {
    actions = [
      "elasticfilesystem:DescribeMountTargets",
      "ec2:DescribeAvailabilityZones",
    ]
    resources = ["*"] # tfsec:ignore:aws-iam-no-policy-wildcards
  }
}

resource "aws_iam_policy" "eks_efs_csi_node" {
  name        = "AmazonEKS_EFS_CSI_Node_Policy-${var.cluster_name}"
  description = "Provides node permissions to use the EFS CSI driver"
  policy      = data.aws_iam_policy_document.eks_efs_csi_node.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_efs_csi_node" {
  role       = "${var.cluster_name}-efs-csi-node-role"
  policy_arn = aws_iam_policy.eks_efs_csi_node.arn
  depends_on = [
    module.eks_efs_csi_node_irsa
  ]
}

resource "aws_efs_file_system" "eks_efs" {
  creation_token = "${var.cluster_name}-efs"
  encrypted      = true
  kms_key_id     = aws_kms_key.this.arn
  tags           = var.tags
}

resource "aws_efs_mount_target" "eks_efs_private" {
  count           = length(var.private_subnets)
  file_system_id  = aws_efs_file_system.eks_efs.id
  subnet_id       = var.private_subnets[count.index]
  security_groups = [aws_security_group.eks_efs_sg.id]
}

resource "helm_release" "aws_efs_csi_driver" {
  name       = "aws-efs-csi-driver"
  namespace  = "kube-system"
  chart      = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver"
  version    = var.efs_csi_driver_version

  values = [
    yamlencode({
      "controller" = {
        "serviceAccount" = {
          "annotations" = {
            "eks.amazonaws.com/role-arn" = "arn:aws:iam::${local.aws_account_id}:role/${var.cluster_name}-efs-csi-controller-role"
          }
        }
        "tags" = var.tags
      }
      "image" = {
        "repository" = "${var.csi_ecr_repository_id}.dkr.ecr.${local.aws_region}.amazonaws.com/eks/aws-efs-csi-driver"
      }
      "node" = {
        "serviceAccount" = {
          "annotations" = {
            "eks.amazonaws.com/role-arn" = "arn:aws:iam::${local.aws_account_id}:role/${var.cluster_name}-efs-csi-node-role"
          }
        }
      }
    })
  ]

  depends_on = [
    module.eks_efs_csi_controller_irsa,
    module.eks,
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
