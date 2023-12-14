data "aws_caller_identity" "default" {}
data "aws_region" "default" {}

locals {
  aws_account_id = data.aws_caller_identity.default.account_id
  aws_region     = data.aws_region.default.name
  aws_auth_roles = [
    for role in var.system_masters_roles : {
      rolearn  = "arn:aws:iam::${local.aws_account_id}:role/${role}"
      username = role
      groups   = ["system:masters"]
    }
  ]

  cert_manager = length(var.cert_manager_route53_zone_id) > 0
}

resource "aws_kms_key" "this" {
  deletion_window_in_days = 10
  description             = "KMS Key for EKS Secrets"
  enable_key_rotation     = true
  tags                    = var.tags
}

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

# EKS Cluster
module "eks" { # tfsec:ignore:aws-ec2-no-public-egress-sgr tfsec:ignore:aws-eks-no-public-cluster-access tfsec:ignore:aws-eks-no-public-cluster-access-to-cidr
  source  = "terraform-aws-modules/eks/aws"
  version = "19.17.2"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  cluster_addons = {
    coredns = {
      most_recent = var.cluster_addons_most_recent
      preserve    = true
    }
    kube-proxy = {
      most_recent = var.cluster_addons_most_recent
      preserve    = true
    }
    vpc-cni = {
      most_recent              = var.cluster_addons_most_recent
      preserve                 = true
      service_account_role_arn = module.eks_vpc_cni_irsa.iam_role_arn
    }
  }
  cluster_addons_timeouts   = var.cluster_addons_timeouts
  cluster_enabled_log_types = var.cluster_enabled_log_types
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.this.arn
    resources        = ["secrets"]
  }

  cluster_endpoint_private_access         = var.cluster_endpoint_private_access
  cluster_endpoint_public_access          = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs    = var.cluster_endpoint_public_access_cidrs
  cluster_security_group_additional_rules = var.cluster_security_group_additional_rules

  aws_auth_roles            = local.aws_auth_roles
  create_kms_key            = false
  manage_aws_auth_configmap = true
  enable_irsa               = true
  subnet_ids                = concat(var.public_subnets, var.private_subnets)
  vpc_id                    = var.vpc_id

  node_security_group_additional_rules = var.node_security_group_additional_rules

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
    ]
  }
  eks_managed_node_groups = var.eks_managed_node_groups

  node_security_group_tags = var.node_security_group_tags
  tags                     = var.tags
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

# Authorize Amazon Load Balancer Controller
module "eks_lb_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.32.1"

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
  version = "5.32.1"

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
  version = "5.32.1"

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


## Kubernetes-level configuration

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--region", local.aws_region, "--cluster-name", module.eks.cluster_name]
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--region", local.aws_region, "--cluster-name", module.eks.cluster_name]
  }
}

## AWS Load Balancer Controller
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  version    = var.lb_controller_version

  values = [
    yamlencode({
      "clusterName" = var.cluster_name
      "defaultTags" = var.tags
      "region"      = local.aws_region
      "serviceAccount" = {
        "annotations" = {
          "eks.amazonaws.com/role-arn"               = "arn:aws:iam::${local.aws_account_id}:role/${var.cluster_name}-lb-role"
          "eks.amazonaws.com/sts-regional-endpoints" = "true"
        }
        "name" = "aws-load-balancer-controller"
      }
      "vpcId" = var.vpc_id
    })
  ]

  depends_on = [
    module.eks_lb_irsa,
    module.eks,
  ]
}

## EBS CSI Storage Driver
resource "helm_release" "aws_ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  chart      = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  version    = var.ebs_csi_driver_version

  values = [
    yamlencode({
      "controller" = {
        "extraVolumeTags" = var.tags
        "serviceAccount" = {
          "annotations" = {
            "eks.amazonaws.com/role-arn" = "arn:aws:iam::${local.aws_account_id}:role/${var.cluster_name}-ebs-csi-role"
          }
        }
      }
      "image" = {
        "repository" = "${var.csi_ecr_repository_id}.dkr.ecr.${local.aws_region}.amazonaws.com/eks/aws-ebs-csi-driver"
      }
    })
  ]

  depends_on = [
    module.eks_ebs_csi_irsa,
    module.eks,
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

# Don't want gp2 storageclass set as default.
resource "kubernetes_annotations" "eks_disable_gp2" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
  force = true

  depends_on = [
    kubernetes_storage_class.eks_ebs_storage_class
  ]
}

## EFS CSI Storage Driver
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

## Nvidia Device Plugin for GPU support
resource "null_resource" "eks_nvidia_device_plugin" {
  count = var.nvidia_device_plugin ? 1 : 0
  provisioner "local-exec" {
    command = "kubectl --context='${var.cluster_name}' apply --filename='https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v${var.nvidia_device_plugin_version}/nvidia-device-plugin.yml'"
  }
  depends_on = [
    helm_release.aws_lb_controller,
  ]
}

## cert-manager
module "cert_manager_irsa" {
  count   = local.cert_manager ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.32.1"

  role_name = "${var.cluster_name}-cert-manager-role"

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "cert-manager:cert-manager",
      ]
    }
  }
  tags = var.tags
}

data "aws_iam_policy_document" "cert_manager" {
  count = local.cert_manager ? 1 : 0
  statement {
    actions = [
      "route53:GetChange"
    ]
    resources = ["arn:aws:route53:::change/*"]
  }

  statement {
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
    ]
    resources = ["arn:aws:route53:::hostedzone/${var.cert_manager_route53_zone_id}"]
  }
}

resource "aws_iam_policy" "cert_manager" {
  count       = local.cert_manager ? 1 : 0
  name        = "AmazonEKS_Cert_Manager_Policy-${var.cluster_name}"
  description = "Provides permissions for cert-manager"
  policy      = data.aws_iam_policy_document.cert_manager[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "cert_manager" {
  count      = local.cert_manager ? 1 : 0
  role       = "${var.cluster_name}-cert-manager-role"
  policy_arn = aws_iam_policy.cert_manager[0].arn
  depends_on = [
    module.cert_manager_irsa[0]
  ]
}

resource "helm_release" "cert_manager" {
  count            = local.cert_manager ? 1 : 0
  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  chart            = "cert-manager"
  repository       = "https://charts.jetstack.io"
  version          = "v${var.cert_manager_version}"
  keyring          = "${path.module}/cert-manager-keyring.gpg"
  verify           = var.helm_verify

  # Set up values so CRDs are installed with the chart, the service account has
  # correct annotations, and that the pod's security context has permissions
  # to read the account token:
  # https://cert-manager.io/docs/configuration/acme/dns01/route53/#service-annotation
  values = [
    yamlencode({
      "installCRDs" = true
      "securityContext" = {
        "fsGroup" = 1001
      }
      "serviceAccount" = {
        "annotations" = {
          "eks.amazonaws.com/role-arn" = "arn:aws:iam::${local.aws_account_id}:role/${var.cluster_name}-cert-manager-role"
        }
      }
    })
  ]

  depends_on = [
    module.cert_manager_irsa[0],
    module.eks,
  ]
}
