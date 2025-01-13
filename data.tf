data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "nlb_sa_role_Principal" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc_provider[0].arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
  }

  statement {
    effect = "Allow"

    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

# Get the VPC data
data "aws_vpc" "vpc" {
  id = var.vpc_id
}

# create the IAM role for the EKS cluster
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
    sid     = "EKSClusterAssumeRole"
  }
}

data "aws_iam_policy_document" "ebs_csi_driver_service_account" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = ["${local.oidc_provider_arn}"]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    # condition {
    #   test     = "StringEquals"
    #   variable = "${aws_eks_cluster.this[0].identity[0].oidc[0].issuer}:aud"
    #   values   = ["sts.amazonaws.com"]
    # }

    # condition {
    #   test     = "StringEquals"
    #   variable = "${aws_eks_cluster.this[0].identity[0].oidc[0].issuer}:sub"
    #   values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    # }
  }
}

data "aws_eks_addon_version" "this" {
  for_each = { for k, v in var.cluster_addons : k => v if local.create_addon }

  addon_name         = try(each.value.name, each.key)
  kubernetes_version = coalesce(var.cluster_version, aws_eks_cluster.this[0].version)
  most_recent        = try(each.value.most_recent, null)

  depends_on = [aws_eks_node_group.this]
}

# IRSA
# Note - this is different from EKS identity provider

data "tls_certificate" "this" {
  # Not available on outposts
  count = local.create_oidc_provider && var.include_oidc_root_ca_thumbprint ? 1 : 0

  url = aws_eks_cluster.this[0].identity[0].oidc[0].issuer
}

# AMI eks node group Release Version
data "aws_ssm_parameter" "eks_ami_release_version" {
  name = "/aws/service/eks/optimized-ami/${aws_eks_cluster.this[0].version}/amazon-linux-2/recommended/release_version"
}

