## AWS Load Balancer Controller

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
