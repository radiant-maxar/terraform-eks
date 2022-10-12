variable "cluster_name" {
  description = "Unique name for the EKS cluster."
  type        = string
}

variable "cert_manager_version" {
  default     = "1.8.2"
  description = "Version of cert-manager to install."
  type        = string
}

variable "cert_manager_route53_zone_id" {
  default     = ""
  description = "Configure cert-manager to issue certificates for this Route53 DNS Zone when provided"
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

variable "ebs_csi_driver_version" {
  default     = "2.12.0"
  description = "Version of the EFS CSI storage driver to install."
  type        = string
}

variable "efs_csi_driver_version" {
  default     = "2.2.9"
  description = "Version of the EFS CSI storage driver to install."
  type        = string
}

variable "eks_managed_node_groups" {
  description = "Managed node groups for the EKS cluster."
  type        = any
}

variable "kubernetes_version" {
  default     = "1.23"
  description = "Kubernetes version to use for the EKS cluster."
  type        = string
}

variable "iam_role_attach_cni_policy" {
  default     = true
  description = "Whether to attach CNI policy to EKS Node groups."
  type        = bool
}

variable "lb_controller_version" {
  default     = "1.4.5"
  description = "Version of the AWS Load Balancer Controller chart to install."
  type        = string
}

variable "cluster_security_group_additional_rules" {
  description = "Additional security group rules to add to the cluster security group created."
  type        = any
  default     = {}
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
  default     = "0.12.3"
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
