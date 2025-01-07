provider "aws" {
  region = "us-east-1"
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws
}

locals {
  name = "my-eks-cluster"
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


#module "vpc_cni_irsa" {
#  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#  version = "~> 5.0"  # Use the latest 5.x version
#
#  role_name = "vpc-cni-irsa"
#
#  attach_vpc_cni_policy = true
#  vpc_cni_enable_ipv4   = true
#
#  oidc_providers = {
#    main = {
#      provider_arn               = module.eks.oidc_provider_arn
#      namespace_service_accounts = ["kube-system:aws-node"]
#    }
#  }
#
#  tags = local.common_tags
#}


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"  # Use the latest 19.x version

  cluster_name    = local.name
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
      ami_type       = "BOTTLEROCKET_x86_64"
      instance_types = ["t3.small"]

      capacity_type  = "SPOT"
      iam_role_attach_cni_policy = true

      min_size     = 1
      max_size     = 2
      desired_size = 1

      labels = {
        # Used to ensure Karpenter runs on nodes that it does not manage
        "karpenter.sh/controller" = "true"
      }
    }
  }

  node_security_group_tags = merge(local.common_tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = local.name
  })

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  # Add some cluster add-ons
  # cluster_addons = {
  #   kube-proxy = {
  #     most_recent = true
  #   }
  #   vpc-cni = {
  #     most_recent              = true
  #     before_compute           = true
  #     service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
  #     configuration_values = jsonencode({
  #       env = {
  #         # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
  #         ENABLE_PREFIX_DELEGATION = "true"
  #         WARM_PREFIX_TARGET       = "1"
  #       }
  #     })
  #   }
  # }

  tags = local.common_tags
}

#module "karpenter" {
#  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
#
#  cluster_name = module.eks.cluster_name
#
#  create_node_iam_role = false
#  node_iam_role_arn    = module.eks.eks_managed_node_groups["karpenter"].iam_role_arn
#  create_access_entry = false
#
#  tags = local.common_tags
#}
#


module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name          = module.eks.cluster_name
  enable_v1_permissions = true

  # Name needs to match role name passed to the EC2NodeClass
  node_iam_role_use_name_prefix   = false
  node_iam_role_name              = local.name
  create_pod_identity_association = true

  # Used to attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.common_tags
}


resource "helm_release" "karpenter" {
  namespace           = "kube-system"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.1.1"
  wait                = false

  values = [
    <<-EOT
    nodeSelector:
      karpenter.sh/controller: 'true'
    dnsPolicy: Default
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    webhook:
      enabled: false
    EOT
  ]
}
