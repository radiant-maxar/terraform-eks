variable "aws_auth_roles" {
  description = "List of role maps to add to the aws-auth configmap"
  type        = list(any)
  default     = []
}

variable "cert_manager_version" {
  default     = "1.13.3"
  description = "Version of cert-manager to install."
  type        = string
}

variable "cert_manager_route53_zone_id" {
  default     = ""
  description = "Configure cert-manager to issue certificates for this Route53 DNS Zone when provided"
  type        = string
}

variable "cluster_addons_most_recent" {
  description = "Indicates whether to use the most recent version of cluster addons"
  type        = bool
  default     = true
}

variable "cluster_addons_overrides" {
  description = "Override parameters for cluster addons."
  type        = map(any)
  default     = {}
}

variable "cluster_addons_timeouts" {
  description = "Create, update, and delete timeout configurations for the cluster addons"
  type        = map(string)
  default = {
    create = "25m"
    delete = "10m"
    update = "15m"
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
  type        = map(any)
  default     = {}
}

variable "create_cluster_security_group" {
  description = "Determines if a security group is created for the cluster. Note: the EKS service creates a primary security group for the cluster by default"
  type        = bool
  default     = true
}

variable "create_node_security_group" {
  description = "Determines whether to create a security group for the node groups or use the existing `node_security_group_id`"
  type        = bool
  default     = true
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

variable "ebs_csi_driver_version" {
  default     = "2.25.0"
  description = "Version of the EFS CSI storage driver to install."
  type        = string
}

variable "efs_csi_driver_version" {
  default     = "2.5.2"
  description = "Version of the EFS CSI storage driver to install."
  type        = string
}

variable "eks_managed_node_groups" {
  description = "Map of managed node groups for the EKS cluster."
  type        = map(any)
  default     = {}
}

variable "fargate_profiles" {
  description = "Map of Fargate Profile definitions to create"
  type        = map(any)
  default     = {}
}

variable "fargate_profile_defaults" {
  description = "Map of Fargate Profile default configurations"
  type        = map(any)
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

variable "karpenter" {
  description = "Whether to use Karpenter with the EKS cluster."
  type        = bool
  default     = false
}

variable "karpenter_version" {
  description = "Version of Karpenter Helm chart to install on the EKS cluster."
  type        = string
  default     = "0.32.3"
}

variable "kms_manage" {
  default     = false
  description = "Manage EKS KMS resource instead of the AWS module"
  type        = bool
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

variable "kubernetes_version" {
  default     = "1.28"
  description = "Kubernetes version to use for the EKS cluster."
  type        = string
}

variable "lb_controller_version" {
  default     = "1.6.1"
  description = "Version of the AWS Load Balancer Controller chart to install."
  type        = string
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

variable "nvidia_device_plugin" {
  default     = false
  description = "Whether to install the Nvidia device plugin driver"
  type        = bool
}

variable "nvidia_device_plugin_version" {
  default     = "0.14.3"
  description = "Version of the Nvidia device plugin to install."
  type        = string
}

variable "private_subnets" {
  description = "IDs of the private subnets in the EKS cluster VPC."
  type        = list(any)
}

variable "public_subnets" {
  description = "IDs of the public subnets in the EKS cluster VPC."
  type        = list(any)
}

variable "system_masters_roles" {
  default     = ["PowerUsers"]
  description = "Roles from the AWS account allowed system:masters to the EKS cluster."
  type        = list(string)
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
