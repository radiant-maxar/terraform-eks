module "karpenter" {
  count = var.karpenter ? 1 : 0
  # XXX: Switch source back to module once v20 is released, refs
  #      terraform-aws-modules/terraform-aws-eks#2858
  source = "github.com/radiant-maxar/terraform-aws-eks//modules/karpenter?ref=v20-prerelease"
  # source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  # version = "20.x.x"
  cluster_name           = var.cluster_name
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn
  tags                   = var.tags
}

resource "helm_release" "karpenter_crd" {
  count            = var.karpenter ? 1 : 0
  create_namespace = true
  name             = "karpenter-crd"
  namespace        = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter-crd"
  version          = "v${var.karpenter_version}"

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
  wait       = var.karpenter_wait

  values = [
    yamlencode({
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = module.karpenter[0].pod_identity_role_arn
        }
      }
      settings = {
        clusterEndpoint   = module.eks.cluster_endpoint
        clusterName       = var.cluster_name
        interruptionQueue = module.karpenter[0].queue_name
      }
      webhook = {
        enabled = true
      }
    }),
    yamlencode(var.karpenter_values),
  ]

  depends_on = [
    helm_release.karpenter_crd[0]
  ]
}
