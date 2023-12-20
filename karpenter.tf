module "karpenter" {
  count   = var.karpenter ? 1 : 0
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "19.21.0"

  cluster_name                               = var.cluster_name
  enable_karpenter_instance_profile_creation = true
  irsa_oidc_provider_arn                     = module.eks.oidc_provider_arn
  tags                                       = var.tags
}

resource "helm_release" "karpenter_crd" {
  count            = var.karpenter ? 1 : 0
  create_namespace = true
  name             = "karpenter-crd"
  namespace        = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter-crd"
  version          = "v${var.karpenter_version}"

  lifecycle {
    ignore_changes = [repository_password]
  }

  depends_on = [
    module.eks,
    module.karpenter[0],
  ]
}

resource "helm_release" "karpenter" {
  count      = var.karpenter ? 1 : 0
  name       = "karpenter"
  namespace  = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "v${var.karpenter_version}"

  values = [
    yamlencode({
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = module.karpenter[0].irsa_arn
        }
      }
      settings = {
        aws = {
          clusterEndpoint        = module.eks.cluster_endpoint
          clusterName            = var.cluster_name
          defaultInstanceProfile = module.karpenter[0].instance_profile_name
          interruptionQueueName  = module.karpenter[0].queue_name
        }
        webhook = {
          enabled = true
        }
      }
    }),
    yamlencode(var.karpenter_values),
  ]

  lifecycle {
    ignore_changes = [repository_password]
  }

  depends_on = [
    helm_release.karpenter_crd[0]
  ]
}
