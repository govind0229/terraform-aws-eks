# EKS manage node group

resource "aws_eks_node_group" "this" {

  for_each = { for k, v in var.eks_managed_node_groups : k => v if var.create }

  cluster_name           = aws_eks_cluster.this[0].name
  node_group_name_prefix = "${each.key}-"
  # node_group_name = try(each.value.name, each.key)
  node_role_arn = local.node_iam_role
  subnet_ids    = coalescelist(var.subnet_ids, var.control_plan_subnet_ids)

  release_version      = local.eks_ami_release_version
  force_update_version = try(each.value.force_update_version, true)

  capacity_type  = try(each.value.capacity_type, var.eks_managed_node_groups.capacity_type, "ON_DEMAND")
  instance_types = try(each.value.instance_types, var.eks_managed_node_groups.instance_types, [""])

  scaling_config {
    min_size     = try(each.value.min_size, 0)
    max_size     = each.value.max_size > 0 ? each.value.max_size : 1
    desired_size = try(each.value.desired_size, 0)
  }

  update_config {
    max_unavailable_percentage = "80"
  }

  depends_on = [
    aws_iam_role_policy_attachment.iam_node_group-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.iam_node_group-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.iam_node_group-AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = {
    "k8s.io/cluster-autoscaler/${aws_eks_cluster.this[0].id}" = "owned"
    "k8s.io/cluster-autoscaler/enabled"                       = true
  }

  launch_template {
    id      = aws_launch_template.eks_node_group_lt[each.key].id
    version = aws_launch_template.eks_node_group_lt[each.key].latest_version
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      scaling_config[0].desired_size,
    ]
  }

  timeouts {
    create = "120m"
    delete = "120m"
    update = "300m"
  }
}

# eks node group lunch templete

resource "aws_launch_template" "eks_node_group_lt" {

  for_each = { for k, v in var.eks_managed_node_groups : k => v if var.create }

  name_prefix = "${each.value.capacity_type == "SPOT" ? "spot" : "ondemand"}-eks-node-group-lt-"

  # Other configurations are omitted for brevity

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.volume_size
      volume_type = var.volume_type
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.modified_tags, {
      Name             = "saas-${var.tags.environment}-${each.value.capacity_type == "SPOT" ? "spot" : "ondemand"}"
      environment_name = var.tags.environment
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.modified_tags, {
      Name             = "saas-${var.tags.environment}-${each.value.capacity_type == "SPOT" ? "spot" : "ondemand"}"
      environment_name = var.tags.environment
    })
  }
}

