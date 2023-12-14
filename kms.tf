resource "aws_kms_key" "this" {
  count                   = var.kms_manage ? 1 : 0
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  description             = "KMS Key for EKS Secrets"
  enable_key_rotation     = true
  tags                    = var.tags
}
