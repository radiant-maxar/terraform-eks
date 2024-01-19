output "cert_manager_role_arn" {
  description = "The cert-manager IRSA role Amazon Resource Name (ARN)"
  value       = var.cert_manager ? module.cert_manager_irsa[0].iam_role_arn : null
}

output "cert_manager_role_name" {
  description = "The cert-manager IRSA role name"
  value       = var.cert_manager ? module.cert_manager_irsa[0].iam_role_name : null
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_primary_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster. Managed node groups use this security group for control-plane-to-data-plane communication. Referred to as 'Cluster security group' in the EKS console"
  value       = module.eks.cluster_primary_security_group_id
}

output "crossplane_role_arn" {
  description = "The Crossplane IRSA role Amazon Resource Name (ARN)"
  value       = var.crossplane && var.crossplane_irsa ? module.crossplane_irsa[0].iam_role_arn : null
}

output "crossplane_role_name" {
  description = "The Crossplane IRSA role name"
  value       = var.crossplane && var.crossplane_irsa ? module.crossplane_irsa[0].iam_role_name : null
}

output "ebs_csi_driver_role_arn" {
  description = "The EBS CSI Storage Driver IRSA role Amazon Resource Name (ARN)"
  value       = var.ebs_csi_driver ? module.eks_ebs_csi_driver_irsa[0].iam_role_arn : null
}

output "ebs_csi_driver_role_name" {
  description = "The EBS CSI Storage Driver IRSA role name"
  value       = var.ebs_csi_driver ? module.eks_ebs_csi_driver_irsa[0].iam_role_name : null
}

output "efs_csi_driver_role_arn" {
  description = "The EFS CSI Storage Driver IRSA role Amazon Resource Name (ARN)"
  value       = var.efs_csi_driver ? module.eks_efs_csi_driver_irsa[0].iam_role_arn : null
}

output "efs_csi_driver_role_name" {
  description = "The EFS CSI Storage Driver IRSA role name"
  value       = var.efs_csi_driver ? module.eks_efs_csi_driver_irsa[0].iam_role_name : null
}

output "eks_managed_node_groups" {
  description = "Map of attribute maps for all EKS managed node groups created"
  value       = module.eks.eks_managed_node_groups
}

output "karpenter_pod_identity_role_arn" {
  description = "The Amazon Resource Name (ARN) specifying the Pod Identity IAM role"
  value       = var.karpenter ? module.karpenter[0].pod_identity_role_arn : null
}

output "karpenter_pod_identity_role_name" {
  description = "The name of the Pod Identity IAM role"
  value       = var.karpenter ? module.karpenter[0].pod_identity_role_name : null
}

output "karpenter_role_arn" {
  description = "The Amazon Resource Name (ARN) specifying the Karpenter IAM role"
  value       = var.karpenter ? module.karpenter[0].role_arn : null
}

output "karpenter_role_name" {
  description = "The name of the Karpenter IAM role"
  value       = var.karpenter ? module.karpenter[0].role_name : null
}

output "kms_key_arn" {
  description = "The Amazon Resource Name (ARN) of the KMS key for the EKS cluster."
  value       = var.kms_manage ? aws_kms_key.this[0].arn : module.eks.kms_key_arn
}

output "kms_key_id" {
  description = "The globally unique identifier for the EKS KMS cluster key"
  value       = var.kms_manage ? aws_kms_key.this[0].id : module.eks.kms_key_id
}

output "lb_controller_role_arn" {
  description = "The AWS Load Balancer Controller IRSA role Amazon Resource Name (ARN)"
  value       = var.lb_controller ? module.eks_lb_irsa[0].iam_role_arn : null
}

output "lb_controller_role_name" {
  description = "The AWS Load Balancer Controller IRSA role name"
  value       = var.lb_controller ? module.eks_lb_irsa[0].iam_role_name : null
}

output "node_security_group_arn" {
  description = "ARN of the EKS node shared security group"
  value       = module.eks.node_security_group_arn
}

output "node_security_group_id" {
  description = "ID of the EKS node shared security group"
  value       = module.eks.node_security_group_id
}

output "oidc_provider" {
  description = "The OpenID Connect identity provider (issuer URL without leading `https://`)"
  value       = module.eks.oidc_provider
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if `enable_irsa = true`"
  value       = module.eks.oidc_provider_arn
}

output "s3_csi_driver_role_arn" {
  description = "The S3 CSI Storage Driver IRSA role Amazon Resource Name (ARN)"
  value       = var.s3_csi_driver ? module.eks_s3_csi_driver_irsa[0].iam_role_arn : null
}

output "s3_csi_driver_role_name" {
  description = "The S3 CSI Storage Driver IRSA role name"
  value       = var.s3_csi_driver ? module.eks_s3_csi_driver_irsa[0].iam_role_name : null
}

output "vpc_cni_role_arn" {
  description = "The vpc-cni Amazon Resource Name (ARN)"
  value       = var.vpc_cni ? module.eks_vpc_cni_irsa[0].iam_role_arn : null
}

output "vpc_cni_role_name" {
  description = "The vpc-cni IRSA role name"
  value       = var.vpc_cni ? module.eks_vpc_cni_irsa[0].iam_role_name : null
}
