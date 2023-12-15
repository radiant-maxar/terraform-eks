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

resource "helm_release" "karpenter" {
  count            = var.karpenter ? 1 : 0
  namespace        = "karpenter"
  create_namespace = true

  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.current.user_name
  repository_password = data.aws_ecrpublic_authorization_token.current.password
  chart               = "karpenter"
  version             = "v${var.karpenter_version}"

  set {
    name  = "settings.aws.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.aws.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter[0].irsa_arn
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = module.karpenter[0].instance_profile_name
  }

  set {
    name  = "settings.aws.interruptionQueueName"
    value = module.karpenter[0].queue_name
  }

  depends_on = [
    module.eks,
    module.karpenter[0],
  ]
}
