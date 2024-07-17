## Crossplane
module "crossplane_irsa" {
  count   = var.crossplane && var.crossplane_irsa ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.41.0"

  role_name = "${var.cluster_name}-crossplane-role"

  assume_role_condition_test = "StringLike"
  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "${var.crossplane_namespace}:${var.crossplane_service_account_name}",
      ]
    }
  }
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "crossplane" {
  count      = var.crossplane && var.crossplane_irsa ? length(var.crossplane_policy_arns) : 0
  role       = module.crossplane_irsa[0].iam_role_name
  policy_arn = var.crossplane_policy_arns[count.index]
  depends_on = [
    module.crossplane_irsa[0]
  ]
}

resource "helm_release" "crossplane" {
  count            = var.crossplane && var.crossplane_helm ? 1 : 0
  chart            = try(var.crossplane_options.chart, "crossplane")
  create_namespace = var.crossplane_namespace == "kube-system" ? false : true
  max_history      = try(var.crossplane_options.max_history, 10)
  name             = try(var.crossplane_options.name, "crossplane")
  namespace        = var.crossplane_namespace
  repository       = try(var.crossplane_options.repository, "https://charts.crossplane.io/stable")
  timeout          = try(var.crossplane_options.timeout, 600)
  values           = [yamlencode(var.crossplane_values)]
  version          = var.crossplane_version
  wait             = var.crossplane_wait

  atomic                     = try(var.crossplane_options.atomic, null)
  cleanup_on_fail            = try(var.crossplane_options.cleanup_on_fail, null)
  dependency_update          = try(var.crossplane_options.dependency_update, null)
  devel                      = try(var.crossplane_options.devel, null)
  disable_openapi_validation = try(var.crossplane_options.disable_openapi_validation, null)
  disable_webhooks           = try(var.crossplane_options.disable_webhooks, null)
  force_update               = try(var.crossplane_options.force_update, null)
  lint                       = try(var.crossplane_options.lint, null)
  recreate_pods              = try(var.crossplane_options.recreate_pods, null)
  render_subchart_notes      = try(var.crossplane_options.render_subchart_notes, null)
  replace                    = try(var.crossplane_options.replace, null)
  repository_key_file        = try(var.crossplane_options.repository_key_file, null)
  repository_cert_file       = try(var.crossplane_options.repository_cert_file, null)
  repository_ca_file         = try(var.crossplane_options.repository_ca_file, null)
  repository_username        = try(var.crossplane_options.repository_username, null)
  repository_password        = try(var.crossplane_options.repository_password, null)
  reset_values               = try(var.crossplane_options.reset_values, null)
  reuse_values               = try(var.crossplane_options.reuse_values, null)
  skip_crds                  = try(var.crossplane_options.skip_crds, null)
  wait_for_jobs              = try(var.crossplane_options.wait_for_jobs, null)

  depends_on = [
    module.eks,
  ]
}
