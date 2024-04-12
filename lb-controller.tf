## AWS Load Balancer Controller

# Authorize Amazon Load Balancer Controller
module "eks_lb_irsa" {
  count   = var.lb_controller ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39.0"

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
  count            = var.lb_controller && var.lb_controller_helm ? 1 : 0
  chart            = try(var.lb_controller_options.chart, "aws-load-balancer-controller")
  create_namespace = var.lb_controller_namespace == "kube-system" ? false : true
  max_history      = try(var.lb_controller_options.max_history, 10)
  name             = try(var.lb_controller_options.name, "aws-load-balancer-controller")
  namespace        = var.lb_controller_namespace
  repository       = try(var.lb_controller_options.repository, "https://aws.github.io/eks-charts")
  timeout          = try(var.lb_controller_options.timeout, 600)
  version          = var.lb_controller_version
  wait             = var.lb_controller_wait

  atomic                     = try(var.lb_controller_options.atomic, null)
  cleanup_on_fail            = try(var.lb_controller_options.cleanup_on_fail, null)
  dependency_update          = try(var.lb_controller_options.dependency_update, null)
  devel                      = try(var.lb_controller_options.devel, null)
  disable_openapi_validation = try(var.lb_controller_options.disable_openapi_validation, null)
  disable_webhooks           = try(var.lb_controller_options.disable_webhooks, null)
  force_update               = try(var.lb_controller_options.force_update, null)
  lint                       = try(var.lb_controller_options.lint, null)
  recreate_pods              = try(var.lb_controller_options.recreate_pods, null)
  render_subchart_notes      = try(var.lb_controller_options.render_subchart_notes, null)
  replace                    = try(var.lb_controller_options.replace, null)
  repository_key_file        = try(var.lb_controller_options.repository_key_file, null)
  repository_cert_file       = try(var.lb_controller_options.repository_cert_file, null)
  repository_ca_file         = try(var.lb_controller_options.repository_ca_file, null)
  repository_username        = try(var.lb_controller_options.repository_username, null)
  repository_password        = try(var.lb_controller_options.repository_password, null)
  reset_values               = try(var.lb_controller_options.reset_values, null)
  reuse_values               = try(var.lb_controller_options.reuse_values, null)
  skip_crds                  = try(var.lb_controller_options.skip_crds, null)
  wait_for_jobs              = try(var.lb_controller_options.wait_for_jobs, null)

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = local.aws_region
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks_lb_irsa[0].iam_role_arn
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  # Values: tags need to be encoded as values unless we get fancy.
  values = [
    yamlencode({
      serviceAccount = {
        annotations = {
          # XXX: This annotation can't be done via `set`.
          "eks.amazonaws.com/sts-regional-endpoints" = "true"
        }
      }
      defaultTags = var.tags
    }),
    yamlencode(var.lb_controller_values),
  ]

  depends_on = [
    module.eks_lb_irsa[0],
    module.eks,
  ]
}
