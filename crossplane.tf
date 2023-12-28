## Crossplane
module "crossplane_irsa" {
  count   = var.crossplane ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.33.0"

  role_name = "${var.cluster_name}-crossplane-role"

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "${var.crossplane_namespace}:crossplane-system:provider-aws-*",
      ]
    }
  }
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "crossplane" {
  count      = var.crossplane ? length(var.crossplane_policy_arns) : 0
  role       = "${var.cluster_name}-crossplane-role"
  policy_arn = var.crossplane_policy_arns[count.index]
  depends_on = [
    module.crossplane_irsa[0]
  ]
}

resource "helm_release" "crossplane" {
  count            = var.crossplane ? 1 : 0
  name             = "crossplane"
  namespace        = var.crossplane_namespace
  create_namespace = var.crossplane_namespace == "kube-system" ? false : true
  chart            = "crossplane"
  repository       = "https://charts.crossplane.io/stable"
  version          = var.crossplane_version
  wait             = var.crossplane_wait

  values = [
    yamlencode({
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = "arn:${local.aws_partition}:iam::${local.aws_account_id}:role/${var.cluster_name}-crossplane-role"
        }
      }
    }),
    yamlencode(var.crossplane_values),
  ]

  depends_on = [
    module.crossplane_irsa[0],
    module.eks,
  ]
}
