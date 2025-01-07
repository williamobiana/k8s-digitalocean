locals {
  vpc_id = module.vpc.vpc_id
  vpc_cidr_block = module.vpc.vpc_cidr_block
  public_subnet_ids = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  
  common_tags = {
    Project     = "EKS-Deployment"
    ManagedBy   = "Terraform"
  }
}


module "vpc" {
  source = "./modules/vpc"
}


module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"  # Use the latest 5.x version

  role_name = "vpc-cni-irsa"

  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = local.common_tags
}


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"  # Use the latest 19.x version

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.27"  # Specify the Kubernetes version you want to use
  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = local.vpc_id
  subnet_ids               = concat(local.private_subnet_ids, local.public_subnet_ids)
  control_plane_subnet_ids = local.private_subnet_ids

  ## EKS Managed Node Group(s) Settings
  #eks_managed_node_groups = {
  #  default_node_group = {
  #    min_size     = 1
  #    max_size     = 3
  #    desired_size = 2
  #
  #    ami_type       = "AL2023_x86_64_STANDARD"
  #    instance_types = ["t3.medium"]
  #    capacity_type  = "ON_DEMAND"
  #    iam_role_attach_cni_policy = true
  #  }
  #}

  # Karpenter Managed Node Group(s) Settings
  eks_managed_node_groups = {
    karpenter = {
      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }

  # Add some cluster add-ons
  cluster_addons = {
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent              = true
      before_compute           = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  tags = local.common_tags
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name = module.eks.cluster_name

  create_node_iam_role = false
  node_iam_role_arn    = module.eks.eks_managed_node_groups["karpenter"].iam_role_arn
  create_access_entry = false

  tags = local.common_tags
}