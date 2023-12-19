## NVIDIA GPU Operator

resource "helm_release" "nvidia_gpu_operator" {
  count            = var.nvidia_gpu_operator ? 1 : 0
  chart            = "gpu-operator"
  create_namespace = true
  name             = "gpu-operator"
  namespace        = "nvidia/gpu-operator"
  repository       = "https://helm.ngc.nvidia.com/nvidia"
  version          = "v${var.nvidia_gpu_operator_version}"

  depends_on = [
    module.eks,
  ]
}
