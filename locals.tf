locals {
  create                                = coalesce(var.create, true)
  cluster_name                          = coalesce(var.cluster_name, "demo-cluster")
  cluster_version                       = coalesce(var.cluster_version, "1.27")
  cluster_security_group_id             = aws_security_group.cluster.id
  cluster_additional_security_group_ids = coalesce(var.cluster_additional_security_group_ids, [])
  cluster_endpoint_public_access        = coalesce(var.cluster_endpoint_public_access, false)
  cluster_endpoint_private_access       = coalesce(var.cluster_endpoint_private_access, true)
  manage_aws_auth_configmap             = coalesce(var.manage_aws_auth_configmap, false)

  #   modified_tags = { for k, v in var.tags : k => v if k != "environment" }

  modified_tags = merge(var.tags, { "environment" = null })

  oidc_provider_arn = local.create_oidc_provider ? aws_iam_openid_connect_provider.oidc_provider[0].arn : null
}



locals {
  node_iam_role_aws_auth = [
    {
      rolearn  = "${local.node_iam_role}"
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    }
  ]
  aws_auth_configmap_data = {
    mapRoles = yamlencode(concat(
      local.node_iam_role_aws_auth,
      var.aws_auth_roles
    ))
    #mapUsers    = yamlencode(var.aws_auth_users)
    #mapAccounts = yamlencode(var.aws_auth_accounts)
  }
}

# IRSA
# Note - this is different from EKS identity provider

locals {
  # Not available on outposts
  create_oidc_provider = local.create && var.enable_irsa

  oidc_root_ca_thumbprint = local.create_oidc_provider && var.include_oidc_root_ca_thumbprint ? [data.tls_certificate.this[0].certificates[0].sha1_fingerprint] : []
}

locals {
  node_iam_role           = try(aws_iam_role.iam_node_group.arn, var.iam_role_arn)
  eks_ami_release_version = try(var.current_eks_ami_release_version == "" ? nonsensitive(data.aws_ssm_parameter.eks_ami_release_version.value) : var.current_eks_ami_release_version)
}
