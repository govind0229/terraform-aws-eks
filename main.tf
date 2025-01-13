# EKS cluster
resource "aws_eks_cluster" "this" {

  count = local.create ? 1 : 0

  name     = "${var.cluster_name}-${var.tags.environment}"
  role_arn = aws_iam_role.this.arn
  version  = local.cluster_version

  vpc_config {
    security_group_ids      = compact(distinct(concat(var.cluster_additional_security_group_ids, [local.cluster_security_group_id])))
    subnet_ids              = coalescelist(var.control_plan_subnet_ids, var.subnet_ids)
    endpoint_public_access  = local.cluster_endpoint_public_access
    endpoint_private_access = local.cluster_endpoint_private_access
    public_access_cidrs     = var.allowlist_endpoints
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.this-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.this-AmazonEKSVPCResourceController,
    aws_cloudwatch_log_group.this,
  ]

  tags_all  = local.modified_tags
}

# Cluster Security Group
resource "aws_security_group" "cluster" {
  name        = "${local.cluster_name}-cluster"
  description = "Cluster communication with worker nodes"

  vpc_id = var.vpc_id

  ingress {
    description = "Worker nodes SG"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]

    self = true
  }

  ingress {
    description     = "Control plan SG"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = var.cluster_additional_security_group_ids
  }

  # Allow all ingress traffic for allowlist
  dynamic "ingress" {
    for_each = var.allowlist_endpoints

    content {
      description = "Allowlist endpoint for ${ingress.value}"
      from_port   = "443"
      to_port     = "443"
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    description = "All"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    ignore_changes = [
      ingress,
      egress,
    ]
  }

  tags = {
    Name = "${local.cluster_name}-${var.environment}-worker-sg"
  }
}

# EKS Addons - https://docs.aws.amazon.com/eks/latest/userguide/addons.html
locals {
  create_addon = var.cluster_addons != null && length(var.cluster_addons) > 0
}

resource "aws_eks_addon" "this" {
  for_each = { for k, v in var.cluster_addons : k => v if !try(v.before_compute, false) && local.create_addon }

  cluster_name = aws_eks_cluster.this[0].name
  addon_name   = try(each.value.name, each.key)

  addon_version               = coalesce(try(each.value.addon_version, null), data.aws_eks_addon_version.this[each.key].version)
  configuration_values        = try(each.value.configuration_values, null)
  preserve                    = try(each.value.preserve, null)
  resolve_conflicts_on_create = try(each.value.resolve_conflicts_on_create, "OVERWRITE")
  resolve_conflicts_on_update = try(each.value.resolve_conflicts_on_update, "OVERWRITE")
  service_account_role_arn    = try(each.value.service_account_role_arn, null)

  timeouts {
    create = try(each.value.timeouts.create, var.cluster_addons_timeouts.create, null)
    # update = try(each.value.timeouts.update, var.cluster_addons_timeouts.update, null)
    delete = try(each.value.timeouts.delete, var.cluster_addons_timeouts.delete, null)
  }

  depends_on = [
    aws_eks_node_group.this,
  ]

  tags = var.tags
}

# resource "aws_eks_addon" "before_compute" {
#   # Not supported on outposts
#   for_each = { for k, v in var.cluster_addons : k => v if try(v.before_compute, false) && local.create_addon }

#   cluster_name = aws_eks_cluster.this[0].name
#   addon_name   = try(each.value.name, each.key)

#   addon_version               = coalesce(try(each.value.addon_version, null), data.aws_eks_addon_version.this[each.key].version)
#   configuration_values        = try(each.value.configuration_values, null)
#   preserve                    = try(each.value.preserve, null)
#   resolve_conflicts_on_create = try(each.value.resolve_conflicts_on_create, "OVERWRITE")
#   resolve_conflicts_on_update = try(each.value.resolve_conflicts_on_update, "OVERWRITE")
#   service_account_role_arn    = try(each.value.service_account_role_arn, null)

#   timeouts {
#     create = try(each.value.timeouts.create, var.cluster_addons_timeouts.create, null)
#     update = try(each.value.timeouts.update, var.cluster_addons_timeouts.update, null)
#     delete = try(each.value.timeouts.delete, var.cluster_addons_timeouts.delete, null)
#   }

#   depends_on = [
#     aws_eks_node_group.this,
#   ]

#   tags = var.tags
# }

# Enabling Control Plane Logging
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/eks/${var.cluster_name}-${var.tags.environment}/cluster"
  retention_in_days = var.logs_retention_in_days

  tags = var.tags

  lifecycle {
    ignore_changes = [ retention_in_days ]
  }
}

# aws-auth configmap
resource "kubernetes_config_map" "aws_auth" {
  count = local.create && var.create_aws_auth_configmap ? 1 : 0

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = local.aws_auth_configmap_data

  lifecycle {
    ignore_changes = [data, metadata[0].labels, metadata[0].annotations]
  }
}

resource "kubernetes_config_map_v1_data" "aws_auth" {
  count = local.create && var.create_aws_auth_configmap ? 1 : 0

  force = true

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = local.aws_auth_configmap_data

  depends_on = [kubernetes_config_map.aws_auth]
}

# IRSA
# Note - this is different from EKS identity provider
resource "aws_iam_openid_connect_provider" "oidc_provider" {
  count = local.create_oidc_provider ? 1 : 0

  client_id_list  = distinct(compact(concat(["sts.amazonaws.com"], var.openid_connect_audiences)))
  thumbprint_list = concat(local.oidc_root_ca_thumbprint, var.custom_oidc_thumbprints)
  url             = aws_eks_cluster.this[0].identity[0].oidc[0].issuer

  tags = merge(
    { Name = "${var.cluster_name}-eks-${var.environment}" },
    var.tags
  )
}

# RBAC Security Audit role for EKS
resource "kubernetes_cluster_role" "security_audit_role" {
  metadata {
    name = var.pre_created_iam_role_name
  }
  rule {
    api_groups = [""]
    resources  = ["nodes", "namespaces", "pods", "configmaps", "endpoints", "events", "limitranges", "persistentvolumeclaims", "podtemplates", "replicationcontrollers", "resourcequotas", "serviceaccounts", "services"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "daemonsets", "statefulsets", "replicasets"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["discovery.k8s.io"]
    resources  = ["endpointslices"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["events.k8s.io"]
    resources  = ["events"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["daemonsets", "deployments", "ingresses", "networkpolicies", "replicasets"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses", "networkpolicies"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["policy"]
    resources  = ["poddisruptionbudgets"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["rolebindings", "roles", "clusterroles", "clusterrolebindings"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["csistoragecapacities"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role_binding" "security_audit_role_binding" {
  metadata {
    name = "${kubernetes_cluster_role.security_audit_role.metadata[0].name}-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.security_audit_role.metadata[0].name
  }
  subject {
    kind      = "User"
    name      = kubernetes_cluster_role.security_audit_role.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "Group"
    name      = kubernetes_cluster_role.security_audit_role.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
}

# RBAC Environment Admin role for EKS
resource "kubernetes_cluster_role" "environment_admin_role" {
  metadata {
    name = "EnvironmentAdmin"
  }
  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

resource "kubernetes_cluster_role_binding" "environment_admin_role_binding" {
  metadata {
    name = "${kubernetes_cluster_role.environment_admin_role.metadata[0].name}-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.environment_admin_role.metadata[0].name
  }
  subject {
    kind      = "User"
    name      = kubernetes_cluster_role.environment_admin_role.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "Group"
    name      = kubernetes_cluster_role.environment_admin_role.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
}

