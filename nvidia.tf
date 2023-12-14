## Nvidia Device Plugin for GPU support
resource "null_resource" "eks_nvidia_device_plugin" {
  count = var.nvidia_device_plugin ? 1 : 0
  provisioner "local-exec" {
    command = "kubectl --context='${var.cluster_name}' apply --filename='https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v${var.nvidia_device_plugin_version}/nvidia-device-plugin.yml'"
  }
  depends_on = [
    helm_release.aws_lb_controller,
  ]
}
