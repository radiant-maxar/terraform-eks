module "karpenter" {
  count   = var.karpenter ? 1 : 0
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.28.0"

  cluster_name                      = var.cluster_name
  enable_irsa                       = true
  irsa_namespace_service_accounts   = ["${var.karpenter_namespace}:karpenter"]
  irsa_oidc_provider_arn            = module.eks.oidc_provider_arn
  node_iam_role_additional_policies = var.iam_role_additional_policies
  node_iam_role_attach_cni_policy   = var.iam_role_attach_cni_policy
  tags                              = var.tags
}

resource "helm_release" "karpenter_crd" {
  count            = var.karpenter && var.karpenter_helm ? 1 : 0
  chart            = try(var.karpenter_options.crd_chart, "karpenter-crd")
  create_namespace = var.karpenter_namespace == "kube-system" ? false : true
  max_history      = try(var.karpenter_options.max_history, 10)
  name             = try(var.karpenter_options.crd_name, "karpenter-crd")
  namespace        = var.karpenter_namespace
  repository       = try(var.karpenter_options.repository, "oci://public.ecr.aws/karpenter")
  timeout          = try(var.karpenter_options.timeout, 600)
  values           = try(var.karpenter_options.crd_values, [])
  version          = var.karpenter_version
  wait             = var.karpenter_wait

  atomic                     = try(var.karpenter_options.atomic, null)
  cleanup_on_fail            = try(var.karpenter_options.cleanup_on_fail, null)
  dependency_update          = try(var.karpenter_options.dependency_update, null)
  devel                      = try(var.karpenter_options.devel, null)
  disable_openapi_validation = try(var.karpenter_options.disable_openapi_validation, null)
  disable_webhooks           = try(var.karpenter_options.disable_webhooks, null)
  force_update               = try(var.karpenter_options.force_update, null)
  lint                       = try(var.karpenter_options.lint, null)
  recreate_pods              = try(var.karpenter_options.recreate_pods, null)
  render_subchart_notes      = try(var.karpenter_options.render_subchart_notes, null)
  replace                    = try(var.karpenter_options.replace, null)
  repository_key_file        = try(var.karpenter_options.repository_key_file, null)
  repository_cert_file       = try(var.karpenter_options.repository_cert_file, null)
  repository_ca_file         = try(var.karpenter_options.repository_ca_file, null)
  repository_username        = try(var.karpenter_options.repository_username, null)
  repository_password        = try(var.karpenter_options.repository_password, null)
  reset_values               = try(var.karpenter_options.reset_values, null)
  reuse_values               = try(var.karpenter_options.reuse_values, null)
  skip_crds                  = try(var.karpenter_options.skip_crds, null)
  wait_for_jobs              = try(var.karpenter_options.wait_for_jobs, null)

  depends_on = [
    module.eks,
    module.karpenter[0],
  ]
}

resource "helm_release" "karpenter" {
  count       = var.karpenter && var.karpenter_helm ? 1 : 0
  chart       = try(var.karpenter_options.chart, "karpenter")
  max_history = try(var.karpenter_options.max_history, 10)
  name        = try(var.karpenter_options.name, "karpenter")
  namespace   = var.karpenter_namespace
  repository  = try(var.karpenter_options.repository, "oci://public.ecr.aws/karpenter")
  timeout     = try(var.karpenter_options.timeout, 600)
  values      = [yamlencode(var.karpenter_values)]
  version     = var.karpenter_version
  wait        = var.karpenter_wait

  atomic                     = try(var.karpenter_options.atomic, null)
  cleanup_on_fail            = try(var.karpenter_options.cleanup_on_fail, null)
  dependency_update          = try(var.karpenter_options.dependency_update, null)
  devel                      = try(var.karpenter_options.devel, null)
  disable_openapi_validation = try(var.karpenter_options.disable_openapi_validation, null)
  disable_webhooks           = try(var.karpenter_options.disable_webhooks, null)
  force_update               = try(var.karpenter_options.force_update, null)
  lint                       = try(var.karpenter_options.lint, null)
  recreate_pods              = try(var.karpenter_options.recreate_pods, null)
  render_subchart_notes      = try(var.karpenter_options.render_subchart_notes, null)
  replace                    = try(var.karpenter_options.replace, null)
  repository_key_file        = try(var.karpenter_options.repository_key_file, null)
  repository_cert_file       = try(var.karpenter_options.repository_cert_file, null)
  repository_ca_file         = try(var.karpenter_options.repository_ca_file, null)
  repository_username        = try(var.karpenter_options.repository_username, null)
  repository_password        = try(var.karpenter_options.repository_password, null)
  reset_values               = try(var.karpenter_options.reset_values, null)
  reuse_values               = try(var.karpenter_options.reuse_values, null)
  skip_crds                  = try(var.karpenter_options.skip_crds, null)
  wait_for_jobs              = try(var.karpenter_options.wait_for_jobs, null)

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter[0].iam_role_arn
  }

  set {
    name  = "settings.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.interruptionQueue"
    value = module.karpenter[0].queue_name
  }

  depends_on = [
    helm_release.karpenter_crd[0]
  ]
}
