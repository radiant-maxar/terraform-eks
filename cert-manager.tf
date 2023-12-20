## cert-manager
locals {
  cert_manager = length(var.cert_manager_route53_zone_id) > 0
}

module "cert_manager_irsa" {
  count   = local.cert_manager ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.33.0"

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
    resources = ["arn:${local.aws_partition}:route53:::change/*"]
  }

  statement {
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
    ]
    resources = ["arn:${local.aws_partition}:route53:::hostedzone/${var.cert_manager_route53_zone_id}"]
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
  wait             = var.cert_manager_wait
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
          "eks.amazonaws.com/role-arn" = "arn:${local.aws_partition}:iam::${local.aws_account_id}:role/${var.cluster_name}-cert-manager-role"
        }
      }
    }),
    yamlencode(var.cert_manager_values),
  ]

  depends_on = [
    module.cert_manager_irsa[0],
    module.eks,
  ]
}
