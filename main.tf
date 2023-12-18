data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_partition  = data.aws_partition.current.partition
  aws_region     = data.aws_region.current.name
  aws_auth_karpenter_roles = var.karpenter ? [
    {
      rolearn  = module.karpenter[0].role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    },
  ] : []
  aws_auth_roles = concat(
    [
      for role in var.system_masters_roles : {
        rolearn  = "arn:${local.aws_partition}:iam::${local.aws_account_id}:role/${role}"
        username = role
        groups   = ["system:masters"]
      }
    ],
    local.aws_auth_karpenter_roles,
    var.aws_auth_roles
  )
}

# EKS Cluster
module "eks" { # tfsec:ignore:aws-ec2-no-public-egress-sgr tfsec:ignore:aws-eks-no-public-cluster-access tfsec:ignore:aws-eks-no-public-cluster-access-to-cidr
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  cluster_addons = merge(
    {
      # Configure CoreDNS to run on Fargate when profiles are provided.
      coredns = {
        configuration_values = length(var.fargate_profiles) > 0 ? jsonencode({ computeType = "Fargate" }) : ""
        most_recent          = var.cluster_addons_most_recent
      }
      eks-pod-identity-agent = {
        most_recent = var.cluster_addons_most_recent
      }
      kube-proxy = {
        most_recent = var.cluster_addons_most_recent
      }
      vpc-cni = {
        most_recent              = var.cluster_addons_most_recent
        service_account_role_arn = module.eks_vpc_cni_irsa.iam_role_arn
      }
    },
    var.cluster_addons_overrides
  )
  cluster_addons_timeouts       = var.cluster_addons_timeouts
  cluster_enabled_log_types     = var.cluster_enabled_log_types
  create_cluster_security_group = var.create_cluster_security_group
  create_node_security_group    = var.create_node_security_group

  cluster_encryption_config = var.kms_manage ? {
    provider_key_arn = aws_kms_key.this[0].arn
    resources        = ["secrets"]
  } : { resources = ["secrets"] }
  create_kms_key                  = var.kms_manage ? false : true
  kms_key_deletion_window_in_days = var.kms_key_deletion_window_in_days
  kms_key_enable_default_policy   = var.kms_key_enable_default_policy

  cluster_endpoint_private_access         = var.cluster_endpoint_private_access
  cluster_endpoint_public_access          = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs    = var.cluster_endpoint_public_access_cidrs
  cluster_security_group_additional_rules = var.cluster_security_group_additional_rules

  aws_auth_roles            = local.aws_auth_roles
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
    vpc_security_group_ids     = aws_security_group.eks_efs_sg[*].id
  }
  eks_managed_node_groups = var.eks_managed_node_groups

  fargate_profiles         = var.fargate_profiles
  fargate_profile_defaults = var.fargate_profile_defaults

  node_security_group_tags = var.node_security_group_tags

  tags = merge(
    var.tags,
    var.karpenter ? { "karpenter.sh/discovery" = var.cluster_name } : {}
  )
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
