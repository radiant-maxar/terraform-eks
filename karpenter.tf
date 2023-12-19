# Required to access Karpenter artifacts in AWS public repositories.
provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}

data "aws_ecrpublic_authorization_token" "current" {
  provider = aws.virginia
}

module "karpenter" {
  count   = var.karpenter ? 1 : 0
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "19.21.0"

  cluster_name           = var.cluster_name
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn
  tags                   = var.tags
}

resource "helm_release" "karpenter_crd" {
  count            = var.karpenter ? 1 : 0
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter-crd"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter-crd"
  version    = "v${var.karpenter_version}"

  # XXX: Unfortunately, AWS ECR credentials leads to resource churn
  #      as the password will change.
  repository_username = data.aws_ecrpublic_authorization_token.current.user_name
  repository_password = data.aws_ecrpublic_authorization_token.current.password

  depends_on = [
    module.eks,
    module.karpenter[0],
  ]
}

resource "helm_release" "karpenter" {
  count            = var.karpenter ? 1 : 0
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "v${var.karpenter_version}"

  # XXX: Unfortunately, AWS ECR credentials leads to resource churn
  #      as the password will change.
  repository_username = data.aws_ecrpublic_authorization_token.current.user_name
  repository_password = data.aws_ecrpublic_authorization_token.current.password

  values = [
    yamlencode({
      "serviceAccount" = {
        "annotations" = {
          "eks.amazonaws.com/role-arn" = module.karpenter[0].irsa_arn
        }
      }
      "settings" = {
        "aws" = {
          "clusterEndpoint"        = module.eks.cluster_endpoint
          "clusterName"            = var.cluster_name
          "defaultInstanceProfile" = module.karpenter[0].instance_profile_name
          "interruptionQueueName"  = module.karpenter[0].queue_name
        }
      }
    }),
    yamlencode(var.karpenter_values),
  ]

  depends_on = [
    helm_release.karpenter_crd[0]
  ]
}
