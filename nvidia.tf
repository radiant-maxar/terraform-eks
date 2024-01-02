## NVIDIA GPU Operator

resource "helm_release" "nvidia_gpu_operator" {
  count            = var.nvidia_gpu_operator ? 1 : 0
  chart            = "gpu-operator"
  create_namespace = var.nvidia_gpu_operator_namespace == "kube-system" ? false : true
  name             = "gpu-operator"
  namespace        = var.nvidia_gpu_operator_namespace
  repository       = "https://helm.ngc.nvidia.com/nvidia"
  wait             = var.nvidia_gpu_operator_wait
  values           = [yamlencode(var.nvidia_gpu_operator_values)]
  version          = "v${var.nvidia_gpu_operator_version}"

  depends_on = [
    module.eks,
  ]
}
