variable "access_entries" {
  description = "Map of access entries to add to the cluster"
  type        = any
  default     = {}
}

variable "authentication_mode" {
  description = "The authentication mode for the cluster. Valid values are `CONFIG_MAP`, `API` or `API_AND_CONFIG_MAP`"
  type        = string
  default     = "API"
}

variable "cert_manager" {
  description = "Install the cert-manager Helm chart when set."
  type        = bool
  default     = false
}

variable "cert_manager_best_practice" {
  description = "Configure cert-manager Helm chart with best practice values."
  type        = bool
  default     = false
}

variable "cert_manager_best_practice_defaults" {
  description = "Additional custom values to merge with best practice values."
  type        = any
  default     = {}
}

variable "cert_manager_namespace" {
  default     = "cert-manager"
  description = "Namespace that cert-manager will use."
  type        = string
}

variable "cert_manager_route53_zone_ids" {
  default     = []
  description = "Configure cert-manager to issue certificates for these Route53 DNS Zone IDs when provided."
  type        = list(string)
}

variable "cert_manager_values" {
  description = "Additional custom values for the cert-manager Helm chart."
  type        = any
  default     = {}
}

variable "cert_manager_version" {
  default     = "1.14.4"
  description = "Version of cert-manager to install."
  type        = string
}

variable "cert_manager_wait" {
  description = "Wait for the cert-manager Helm chart installation to complete."
  type        = bool
  default     = true
}

variable "cluster_addons_most_recent" {
  description = "Indicates whether to use the most recent version of cluster addons"
  type        = bool
  default     = true
}

variable "cluster_addons_overrides" {
  description = "Override parameters for cluster addons."
  type        = any
  default     = {}
}

variable "cluster_addons_timeouts" {
  description = "Create, update, and delete timeout configurations for the cluster addons"
  type        = map(string)
  default = {
    create = "10m"
    delete = "10m"
    update = "10m"
  }
}

variable "cluster_enabled_log_types" {
  description = "A list of the desired control plane logs to enable. For more information, see Amazon EKS Control Plane Logging documentation (https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html)"
  default     = ["api", "authenticator", "audit", "scheduler", "controllerManager"]
  type        = list(string)
}

variable "cluster_endpoint_private_access" {
  description = "Indicates whether or not the Amazon EKS private API server endpoint is enabled"
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access" {
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks which can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_name" {
  description = "Unique name for the EKS cluster."
  type        = string
}

variable "cluster_security_group_additional_rules" {
  description = "Additional security group rules to add to the cluster security group created."
  type        = any
  default     = {}
}

variable "create_cluster_security_group" {
  description = "Determines if a security group is created for the cluster. Note: the EKS service creates a primary security group for the cluster by default"
  type        = bool
  default     = true
}

variable "coredns" {
  description = "Indicates whether to install the CoreDNS cluster addon."
  type        = bool
  default     = true
}

variable "coredns_options" {
  description = "Custom options for the CoreDNS addon."
  type        = any
  default     = {}
}

variable "create_node_security_group" {
  description = "Determines whether to create a security group for the node groups or use the existing `node_security_group_id`"
  type        = bool
  default     = true
}

variable "crossplane" {
  description = "Indicates whether to install Crossplane."
  type        = bool
  default     = false
}

variable "crossplane_irsa" {
  description = "Indicates whether to create an IRSA role for Crossplane."
  type        = bool
  default     = true
}

variable "crossplane_namespace" {
  default     = "crossplane-system"
  description = "Namespace that Crossplane will use."
  type        = string
}

variable "crossplane_policy_arns" {
  default     = []
  description = "Configure and install Crossplane with the given AWS IAM Policy ARNs."
  type        = list(string)
}

variable "crossplane_service_account_name" {
  default     = "provider-aws-*"
  description = "Crossplane service account name for IRSA binding."
  type        = string
}

variable "crossplane_values" {
  description = "Additional custom values for the Crossplane Helm chart."
  type        = any
  default     = {}
}

variable "crossplane_wait" {
  description = "Wait for the Crossplane Helm chart installation to complete."
  type        = bool
  default     = true
}

variable "crossplane_version" {
  default     = "1.15.0"
  description = "Version of Crossplane Helm chart to install."
  type        = string
}

# The ECR repository is not the same for every region, in particular
# those for govcloud:
#   https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html
variable "csi_ecr_repository_id" {
  default     = "602401143452"
  description = "The ECR repository ID for retrieving the AWS EFS CSI Driver."
  type        = string
}

variable "default_ami_type" {
  default     = "AL2_x86_64"
  description = "Default EC2 AMI type for EKS cluster nodes."
  type        = string
}

variable "default_capacity_type" {
  default     = "ON_DEMAND"
  description = "Default EC2 capacity type for EKS cluster nodes."
  type        = string
}

variable "default_desired_size" {
  default     = 1
  description = "Default EKS node group desired size."
  type        = number
}

variable "default_min_size" {
  default     = 1
  description = "Default EKS node group min size."
  type        = number
}

variable "default_max_size" {
  default     = 4
  description = "Default EKS node group max size."
  type        = number
}

variable "ebs_csi_driver" {
  description = "Install and configure the EBS CSI storage driver."
  type        = bool
  default     = true
}

variable "ebs_csi_driver_options" {
  description = "Additional custom values for the EBS CSI Driver addon."
  type        = any
  default     = {}
}

variable "ebs_storage_class_mount_options" {
  default     = []
  description = "EBS storage class mount options."
  type        = list(string)
}

variable "ebs_storage_class_parameters" {
  description = "EBS storage class parameters."
  type        = any
  default     = {}
}

variable "efs_csi_driver" {
  description = "Install and configure the EFS CSI storage driver."
  type        = bool
  default     = true
}

variable "efs_csi_driver_namespace" {
  default     = "kube-system"
  description = "Namespace that EFS CSI storage driver will use."
  type        = string
}

variable "efs_csi_driver_values" {
  description = "Additional custom values for the EFS CSI Driver Helm chart."
  type        = any
  default     = {}
}

variable "efs_csi_driver_version" {
  default     = "2.5.6"
  description = "Version of the EFS CSI storage driver to install."
  type        = string
}

variable "efs_csi_driver_wait" {
  description = "Wait for the EFS CSI storage driver Helm chart install to complete."
  type        = bool
  default     = true
}

variable "efs_storage_class_mount_options" {
  default     = []
  description = "EFS storage class mount options."
  type        = list(string)
}

variable "efs_storage_class_parameters" {
  description = "EFS storage class parameters."
  type        = any
  default = {
    "provisioningMode" = "efs-ap"
    "directoryPerms"   = "755"
    "uid"              = "0"
    "gid"              = "0"
  }
}

variable "eks_managed_node_groups" {
  description = "Map of managed node groups for the EKS cluster."
  type        = any
  default     = {}
}

variable "eks_pod_identity_agent" {
  description = "Indicates whether to install the eks-pod-identity-agent cluster addon."
  type        = bool
  default     = true
}

variable "eks_pod_identity_agent_options" {
  description = "Custom options for the eks-pod-identity-agent addon."
  type        = any
  default     = {}
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Indicates whether or not to add the cluster creator (the identity used by Terraform) as an administrator via access entry"
  type        = bool
  default     = false
}

variable "fargate_profiles" {
  description = "Map of Fargate Profile definitions to create."
  type        = any
  default     = {}
}

variable "fargate_profile_defaults" {
  description = "Map of Fargate Profile default configurations."
  type        = any
  default     = {}
}

variable "helm_verify" {
  default     = true
  description = "Whether to verify GPG signatures for Helm charts that provide them."
  type        = bool
}

variable "iam_role_attach_cni_policy" {
  default     = true
  description = "Whether to attach CNI policy to EKS Node groups."
  type        = bool
}

variable "iam_role_additional_policies" {
  description = "Additional policies to be attached to EKS Node groups"
  type        = map(string)
  default     = {}
}

variable "karpenter" {
  description = "Whether to use Karpenter with the EKS cluster."
  type        = bool
  default     = false
}

variable "karpenter_namespace" {
  default     = "kube-system"
  description = "Namespace that Karpenter will use."
  type        = string
}

variable "karpenter_values" {
  description = "Additional custom values to use when installing the Karpenter Helm chart."
  type        = any
  default     = {}
}

variable "karpenter_version" {
  description = "Version of Karpenter Helm chart to install on the EKS cluster."
  type        = string
  default     = "0.35.1"
}

variable "karpenter_wait" {
  description = "Wait for the Karpenter Helm chart installation to complete."
  type        = bool
  default     = true
}

variable "kms_manage" {
  default     = false
  description = "Manage EKS KMS resource instead of the AWS module"
  type        = bool
}

variable "kms_key_administrators" {
  description = "A list of IAM ARNs for [key administrators](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-administrators). If no value is provided, the current caller identity is used to ensure at least one key admin is available"
  type        = list(string)
  default     = []
}

variable "kms_key_aliases" {
  description = "A list of aliases to create. Note - due to the use of `toset()`, values must be static strings and not computed values"
  type        = list(string)
  default     = []
}

variable "kms_key_deletion_window_in_days" {
  description = "The waiting period, specified in number of days. After the waiting period ends, AWS KMS deletes the KMS key. If you specify a value, it must be between `7` and `30`, inclusive."
  type        = number
  default     = 10
}

variable "kms_key_enable_default_policy" {
  description = "Specifies whether to enable the default key policy. Defaults to `true` to workaround EFS permissions."
  type        = bool
  default     = true
}

variable "kms_key_enable_rotation" {
  description = "Specifies whether key rotation is enabled"
  type        = bool
  default     = true
}

variable "kms_key_owners" {
  description = "A list of IAM ARNs for those who will have full key permissions (`kms:*`)"
  type        = list(string)
  default     = []
}

variable "kms_key_override_policy_documents" {
  description = "List of IAM policy documents that are merged together into the exported document. In merging, statements with non-blank `sid`s will override statements with the same `sid`"
  type        = list(string)
  default     = []
}

variable "kms_key_service_users" {
  description = "A list of IAM ARNs for [key service users](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-service-integration)"
  type        = list(string)
  default     = []
}

variable "kms_key_source_policy_documents" {
  description = "List of IAM policy documents that are merged together into the exported document. Statements must have unique `sid`s"
  type        = list(string)
  default     = []
}

variable "kms_key_users" {
  description = "A list of IAM ARNs for [key users](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-users)"
  type        = list(string)
  default     = []
}

variable "kube_proxy" {
  description = "Indicates whether to install the kube-proxy cluster addon."
  type        = bool
  default     = true
}

variable "kube_proxy_options" {
  description = "Custom options for the kube-proxy addon."
  type        = any
  default     = {}
}

variable "kubernetes_version" {
  default     = "1.29"
  description = "Kubernetes version to use for the EKS cluster."
  type        = string
}

variable "lb_controller" {
  description = "Install and configure the AWS Load Balancer Controller."
  type        = bool
  default     = true
}

variable "lb_controller_namespace" {
  default     = "kube-system"
  description = "Namespace that AWS Load Balancer Controller will use."
  type        = string
}

variable "lb_controller_values" {
  description = "Additional custom values for the AWS Load Balancer Controller Helm chart."
  type        = any
  default     = {}
}

variable "lb_controller_version" {
  default     = "1.7.1"
  description = "Version of the AWS Load Balancer Controller chart to install."
  type        = string
}

variable "lb_controller_wait" {
  description = "Wait for the AWS Load Balancer Controller Helm chart install to complete."
  type        = bool
  default     = true
}

variable "node_security_group_additional_rules" {
  default = {
    ingress_self_all = {
      description = "Node to node accept all"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_self_all = {
      description = "Node to node all"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      self        = true
    }
  }
  description = "Additional node security group rules."
  type        = any
}

variable "node_security_group_tags" {
  description = "A map of additional tags to add to the node security group created"
  type        = map(string)
  default     = {}
}

variable "nvidia_gpu_operator" {
  default     = false
  description = "Whether to install the NVIDIA GPU Operator."
  type        = bool
}

variable "nvidia_gpu_operator_namespace" {
  default     = "gpu-operator"
  description = "Namespace that NVIDIA GPU Operator will use."
  type        = string
}

variable "nvidia_gpu_operator_values" {
  description = "Additional custom values for the NVIDIA GPU Operator Helm chart."
  type        = any
  default     = {}
}

variable "nvidia_gpu_operator_version" {
  default     = "23.9.2"
  description = "Version of the NVIDIA GPU Operator Helm chart to install."
  type        = string
}

variable "nvidia_gpu_operator_wait" {
  description = "Wait for the NVIDIA GPU Operator Helm chart installation to complete."
  type        = bool
  default     = true
}

variable "private_subnets" {
  description = "IDs of the private subnets in the EKS cluster VPC."
  type        = list(any)
}

variable "public_subnets" {
  description = "IDs of the public subnets in the EKS cluster VPC."
  type        = list(any)
}

variable "snapshot_controller" {
  description = "Indicates whether to install the snapshot-controller cluster addon."
  type        = bool
  default     = true
}

variable "snapshot_controller_options" {
  description = "Custom options for the snapshot-controller addon."
  type        = any
  default     = {}
}

variable "system_masters_roles" {
  default     = ["PowerUsers"]
  description = "Roles from the AWS account allowed system:masters to the EKS cluster."
  type        = list(string)
}

variable "s3_csi_driver" {
  description = "Install and configure the S3 CSI storage driver addon."
  type        = bool
  default     = false
}

variable "s3_csi_driver_bucket_names" {
  description = "The bucket names that the S3 CSI storage driver addon has permission to use."
  type        = list(string)
  default     = []
}

variable "s3_csi_driver_options" {
  description = "Additional custom values for the S3 CSI storage driver addon."
  type        = any
  default     = {}
}

variable "tags" {
  default     = {}
  description = "Default AWS tags to apply to resources."
  type        = map(string)
}

variable "vpc_cidr" {
  description = "CIDR for VPC that hosts EKS cluster VPC."
  type        = string
}

variable "vpc_id" {
  description = "EKS Cluster VPC ID"
  type        = string
}

variable "vpc_cni" {
  description = "Indicates whether to install the vpc-cni cluster addon."
  type        = bool
  default     = true
}

variable "vpc_cni_options" {
  description = "Custom options for the vpc-cni addon."
  type        = any
  default     = {}
}
