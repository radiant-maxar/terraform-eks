# Terraform EKS

This module provides an opinionated way to configure an AWS EKS cluster using:

* [terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks)
* [terraform-aws-iam](https://github.com/terraform-aws-modules/terraform-aws-iam)

## Features

* [VPC CNI](https://docs.aws.amazon.com/eks/latest/userguide/cni-iam-role.html) networking, using IRSA role.
* [EBS CSI](https://docs.aws.amazon.com/eks/latest/userguide/managing-ebs-csi.html) with `gp3` devices configured as the default storage class (`ebs-sc`).
* [EFS CSI](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html) support enabled, along with an EFS file system for creating [access points](https://docs.aws.amazon.com/efs/latest/ug/efs-access-points.html) for `ReadWriteMany` persistent volume support with the `efs-sc` storage class.
* Overcoming integration issues and bugs Amazon hasn't documented or fixed yet using these EKS features.

## Example

Here's an example using a VPC defined using the [terraform-aws-vpc](https://github.com/terraform-aws-modules/terraform-aws-vpc) module:

```
data "aws_availability_zones" "default" {}

locals {
  cluster_name   = "test-eks"
  vpc_azs        = slice(data.aws_availability_zones.default.names, 0, 2)
  vpc_cidr       = "10.100.0.0/16"
  vpc_subnets    = cidrsubnets(local.vpc_cidr, 6, 6, 4, 4)

  private_subnets         = slice(local.vpc_subnets, 2, 4)
  private_node_defaults   = {
    block_device_mappings = {
      root = {
        device_name = "/dev/xvda"
        ebs = {
          delete_on_termination = true
          volume_size           = 100
          volume_type           = "gp3"
        }
      }
    }
    instance_types = ["m6i.2xlarge"]
    labels = {
      "network" = "private"
    }
  }

  public_subnets         = slice(local.vpc_subnets, 0, 2)
  public_node_defaults = {
    block_device_mappings = {
      root = {
        device_name = "/dev/xvda"
        ebs = {
          delete_on_termination = true
          volume_size           = 20
          volume_type           = "gp3"
        }
      }
    }
    instance_types  = ["t3a.large"]
    labels = {
      "network" = "public"
    }
  }
}

module "eks_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.0"

  azs  = local.vpc_azs
  cidr = local.vpc_cidr
  name = local.cluster_name

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = false

  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  # These additional tags are necessary to create ALB/NLBs dynamically.
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
}

module "eks" {
  source = "github.com/radiant-maxar/terraform-eks"

  cluster_name    = local.cluster_name
  private_subnets = module.eks_vpc.private_subnets
  public_subnets  = module.eks_vpc.public_subnets
  vpc_cidr        = local.vpc_cidr
  vpc_id          = module.eks_vpc.vpc_id

  iam_role_attach_cni_policy = true

  eks_managed_node_groups = {
    private = merge(
      local.private_node_defaults,
      {
        subnet_ids = [module.eks_vpc.private_subnets[0]]
      }
    )
    public-1 = merge(
      local.public_node_defaults,
      {
        subnet_ids = [module.eks_vpc.public_subnets[0]]
      }
    )
    public-2 = merge(
      local.public_node_defaults,
      {
        subnet_ids = [module.eks_vpc.public_subnets[1]]
      }
    )
  }
}
```

## Known Issues

Persistent volumes or ALBs (`Ingress`) or NLBs (`LoadBalancer`) that aren't deleted prior to cluster removal will persist.  In the case of ALB/NLBs their dynamic security groups may prevent deletion of the VPC associated with the EKS cluster.
