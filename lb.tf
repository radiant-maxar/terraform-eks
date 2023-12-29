## AWS Load Balancer Controller

# Authorize Amazon Load Balancer Controller
module "eks_lb_irsa" {
  count   = var.lb_controller ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.33.0"

  role_name                              = "${var.cluster_name}-lb-role"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${var.lb_controller_namespace}:aws-load-balancer-controller"]
    }
  }

  tags = var.tags
}

resource "helm_release" "aws_lb_controller" {
  count            = var.lb_controller ? 1 : 0
  chart            = "aws-load-balancer-controller"
  create_namespace = var.lb_controller_namespace == "kube-system" ? false : true
  name             = "aws-load-balancer-controller"
  namespace        = var.lb_controller_namespace
  repository       = "https://aws.github.io/eks-charts"
  version          = var.lb_controller_version
  wait             = var.lb_controller_wait

  values = [
    yamlencode({
      clusterName = var.cluster_name
      defaultTags = var.tags
      region      = local.aws_region
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn"               = "arn:${local.aws_partition}:iam::${local.aws_account_id}:role/${var.cluster_name}-lb-role"
          "eks.amazonaws.com/sts-regional-endpoints" = "true"
        }
        name = "aws-load-balancer-controller"
      }
      vpcId = var.vpc_id
    }),
    yamlencode(var.lb_controller_values),
  ]

  depends_on = [
    module.eks_lb_irsa[0],
    module.eks,
  ]
}
