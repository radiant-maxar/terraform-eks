## EBS CSI Storage Driver

# Allow PVCs backed by EBS
module "eks_ebs_csi_driver_irsa" {
  count   = var.ebs_csi_driver ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.33.1"

  role_name             = "${var.cluster_name}-ebs-csi-role"
  attach_ebs_csi_policy = true
  ebs_csi_kms_cmk_ids   = [var.kms_manage ? aws_kms_key.this[0].arn : module.eks.kms_key_arn]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}

# Make EBS CSI with gp3 default storage driver
resource "kubernetes_storage_class" "eks_ebs_storage_class" {
  count = var.ebs_csi_driver ? 1 : 0

  metadata {
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
    labels = {}
    name   = "ebs-sc"
  }

  mount_options = var.ebs_storage_class_mount_options
  parameters = merge(
    var.ebs_storage_class_parameters,
    {
      kmsKeyId = var.kms_manage ? aws_kms_key.this[0].id : module.eks.kms_key_id
    }
  )
  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"

  depends_on = [
    module.eks,
  ]
}

# Don't want gp2 storageclass set as default.
resource "kubernetes_annotations" "eks_disable_gp2" {
  count = var.ebs_csi_driver ? 1 : 0

  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
  force = true

  depends_on = [
    kubernetes_storage_class.eks_ebs_storage_class[0]
  ]
}
