## NVIDIA GPU Operator

resource "helm_release" "nvidia_gpu_operator" {
  count            = var.nvidia_gpu_operator ? 1 : 0
  chart            = try(var.nvidia_gpu_operator_options.chart, "gpu-operator")
  create_namespace = var.nvidia_gpu_operator_namespace == "kube-system" ? false : true
  max_history      = try(var.nvidia_gpu_operator_options.max_history, 10)
  name             = try(var.nvidia_gpu_operator_options.name, "gpu-operator")
  namespace        = var.nvidia_gpu_operator_namespace
  repository       = try(var.nvidia_gpu_operator_options.repository, "https://helm.ngc.nvidia.com/nvidia")
  wait             = var.nvidia_gpu_operator_wait
  timeout          = try(var.nvidia_gpu_operator_options.timeout, 600)
  values           = [yamlencode(var.nvidia_gpu_operator_values)]
  version          = "v${var.nvidia_gpu_operator_version}"

  atomic                     = try(var.nvidia_gpu_operator_options.atomic, null)
  cleanup_on_fail            = try(var.nvidia_gpu_operator_options.cleanup_on_fail, null)
  dependency_update          = try(var.nvidia_gpu_operator_options.dependency_update, null)
  devel                      = try(var.nvidia_gpu_operator_options.devel, null)
  disable_openapi_validation = try(var.nvidia_gpu_operator_options.disable_openapi_validation, null)
  disable_webhooks           = try(var.nvidia_gpu_operator_options.disable_webhooks, null)
  force_update               = try(var.nvidia_gpu_operator_options.force_update, null)
  lint                       = try(var.nvidia_gpu_operator_options.lint, null)
  recreate_pods              = try(var.nvidia_gpu_operator_options.recreate_pods, null)
  render_subchart_notes      = try(var.nvidia_gpu_operator_options.render_subchart_notes, null)
  replace                    = try(var.nvidia_gpu_operator_options.replace, null)
  repository_key_file        = try(var.nvidia_gpu_operator_options.repository_key_file, null)
  repository_cert_file       = try(var.nvidia_gpu_operator_options.repository_cert_file, null)
  repository_ca_file         = try(var.nvidia_gpu_operator_options.repository_ca_file, null)
  repository_username        = try(var.nvidia_gpu_operator_options.repository_username, null)
  repository_password        = try(var.nvidia_gpu_operator_options.repository_password, null)
  reset_values               = try(var.nvidia_gpu_operator_options.reset_values, null)
  reuse_values               = try(var.nvidia_gpu_operator_options.reuse_values, null)
  skip_crds                  = try(var.nvidia_gpu_operator_options.skip_crds, null)
  wait_for_jobs              = try(var.nvidia_gpu_operator_options.wait_for_jobs, null)

  depends_on = [
    module.eks,
  ]
}
