output "cluster_endpoint" {
  value = aws_eks_cluster.this[0].endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.this[0].certificate_authority[0].data
}

output "cluster_name" {
  value = aws_eks_cluster.this[0].id
}

output "cluster_node_group_name" {
  value = [for ng in aws_eks_node_group.this : ng.node_group_name]
}

output "cluster_identity_oidc_issuer" {
  value = aws_eks_cluster.this[0].identity[0].oidc[0].issuer
}

output "cluster_identity_oidc_issuer_arn" {
  value = aws_iam_openid_connect_provider.oidc_provider[0].arn
}

output "cluster_identity_oidc_issuer_name" {
  value = replace(aws_iam_openid_connect_provider.oidc_provider[0].url, "https://", "")
}

output "cluster_security_group_id" {
  value = aws_eks_cluster.this[0].vpc_config[0].cluster_security_group_id
}

# Node Group

output "worker_nodes_security_group_id" {
  value = aws_security_group.cluster.id
}

output "node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = try(aws_eks_node_group.this[0].arn, null)
}

output "node_group_id" {
  description = "EKS Cluster name and EKS Node Group name separated by a colon (`:`)"
  value       = try(aws_eks_node_group.this[0].id, null)
}

output "node_group_resources" {
  description = "List of objects containing information about underlying resources"
  value       = try(aws_eks_node_group.this[0].resources, null)
}

output "node_group_autoscaling_group_names" {
  description = "List of the autoscaling group names"
  value       = try(flatten(aws_eks_node_group.this[0].resources[*].autoscaling_groups[*].name), [])
}

output "node_group_status" {
  description = "Status of the EKS Node Group"
  value       = try(aws_eks_node_group.this[0].status, null)
}

output "node_group_labels" {
  description = "Map of labels applied to the node group"
  value       = try(aws_eks_node_group.this[0].labels, {})
}

# Helm Release Outputs
output "lbc_helm_metadata" {
  description = "Metadata Block outlining status of the deployed release."
  value       = helm_release.aws_load_balancer_controller.metadata
}

output "current_eks_ami_release_version" {
  value = local.eks_ami_release_version
}

output "latest_eks_ami_release_version" {
  value     = nonsensitive(data.aws_ssm_parameter.eks_ami_release_version.value)
  sensitive = false
}

output "ebs_csi_driver_service_account_arn" {
  value = aws_iam_role.ebs_csi_driver_service_account.arn
}

output "aws_elb_controller_service_account_arn" {
  value = aws_iam_role.nlb_service_account.arn
}

output "aws_cloudwatch_log_group_name" {
  value = aws_cloudwatch_log_group.this.name
}
