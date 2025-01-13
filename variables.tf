variable "create" {
  description = "Controls if EKS resources should be created (affects nearly all resources)"
  type        = bool
  default     = true
}

variable "subnet_ids" {
  type    = list(string)
  default = []
}

variable "control_plan_subnet_ids" {
  type    = list(string)
  default = []
}

variable "cluster_name" {
  type    = string
  default = ""
}

variable "cluster_version" {
  type    = string
  default = ""
}

variable "cluster_endpoint_public_access" {
  type    = bool
  default = false
}

variable "cluster_endpoint_private_access" {
  type    = bool
  default = true
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "cluster_additional_security_group_ids" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "aws_auth_roles" {
  description = "Contents of the aws-auth configmap. Used if manage_aws_auth_configmap is set to false"
  type        = any
  default     = {}
}

variable "aws_auth_users" {
  description = "Contents of the aws-auth configmap. Used if manage_aws_auth_configmap is set to false"
  type        = any
  default     = {}
}

variable "aws_auth_accounts" {
  description = "Contents of the aws-auth configmap. Used if manage_aws_auth_configmap is set to false"
  type        = any
  default     = {}
}

variable "create_aws_auth_configmap" {
  description = "Determines whether to create the aws-auth configmap. NOTE - this is only intended for scenarios where the configmap does not exist (i.e. - when using only self-managed node groups). Most users should use `manage_aws_auth_configmap`"
  type        = bool
  default     = false
}

variable "iam_role_arn" {
  description = "IAM role ARN to use for the EKS cluster. Defaults to `aws_iam_role.eks_cluster.arn`"
  type        = string
  default     = ""
}

variable "allowlist_endpoints" {
  description = "List of CIDR blocks to allow communication to the EKS cluster API server endpoint from. By default, traffic is allowed from anywhere."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

################################################################################
# EKS Addons
################################################################################

variable "cluster_addons" {
  description = "Map of cluster addon configurations to enable for the cluster. Addon name can be the map keys or set with `name`"
  type        = any
  default     = {}
}

variable "cluster_addons_timeouts" {
  description = "Create, update, and delete timeout configurations for the cluster addons"
  type        = map(string)
  default     = {}
}

variable "manage_aws_auth_configmap" {
  description = "Whether to manage the aws-auth configmap with the EKS cluster. Set to false if you want to manage this on your own"
  type        = bool
  default     = false
}

################################################################################
# EKS Node Group
################################################################################

variable "eks_managed_node_group_defaults" {
  description = "Map of maps of node group configurations to create with the cluster. Node group name can be the map keys or set with `name`"
  type        = any
  default     = {}
}

variable "eks_managed_node_groups" {
  description = "Map of maps of node group configurations to create with the cluster. Node group name can be the map keys or set with `name`"
  type        = any
  default     = {}
}

variable "capacity_type" {
  description = "The capacity type for your managed node group. Valid values are ON_DEMAND or SPOT. Defaults to ON_DEMAND."
  type        = string
  default     = "ON_DEMAND"
}

variable "instance_types" {
  description = "Set of instance types associated with the EKS Node Group. Defaults to [\"t3.medium\"]"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = ""
}

variable "teams" {
  description = "Teams"
  type        = string
  default     = ""
}

variable "Terraform" {
  description = "Terraform"
  type        = string
  default     = true
}

# scaling_config values

variable "min_size" {
  description = "Minimum number of instances/nodes"
  type        = number
  default     = 3
}

variable "max_size" {
  description = "Maximum number of instances/nodes"
  type        = number
  default     = 10
}

variable "desired_size" {
  description = "Desired number of instances/nodes"
  type        = number
  default     = 5
}

variable "update_config" {
  description = "Configuration block of settings for max unavailable resources during node group updates"
  type        = map(string)
  default = {
    max_unavailable_percentage = 33
  }
}

variable "current_eks_ami_release_version" {
  type = string
}

################################################################################
# Autoscaling Group Schedule
################################################################################

variable "create_schedule" {
  description = "Determines whether to create autoscaling group schedule or not"
  type        = bool
  default     = true
}

variable "schedules" {
  description = "Map of autoscaling group schedule to create"
  type        = map(any)
  default     = {}
}

variable "create_oidc_provider" {
  description = "Determines whether to create OIDC provider or not"
  type        = bool
  default     = true
}

################################################################################
# IRSA
################################################################################

variable "enable_irsa" {
  description = "Determines whether to create an OpenID Connect Provider for EKS to enable IRSA"
  type        = bool
  default     = true
}

variable "openid_connect_audiences" {
  description = "List of OpenID Connect audience client IDs to add to the IRSA provider"
  type        = list(string)
  default     = []
}

variable "include_oidc_root_ca_thumbprint" {
  description = "Determines whether to include the root CA thumbprint in the OpenID Connect (OIDC) identity provider's server certificate(s)"
  type        = bool
  default     = true
}

variable "custom_oidc_thumbprints" {
  description = "Additional list of server certificate thumbprints for the OpenID Connect (OIDC) identity provider's server certificate(s)"
  type        = list(string)
  default     = []
}

#Variable for Security role name
variable "pre_created_iam_role_name" {
  description = "The ARN of the pre-created IAM role"
  type        = string
  default     = ""
}

variable "volume_size" {
  description = "The size of the EBS volume for the nodes"
  type        = number
  default     = 20
}

variable "volume_type" {
  description = "The type of EBS volume for the nodes"
  type        = string
  default     = "gp2"
}

variable "logs_retention_in_days" {
  description = "The number of days to retain log events"
  type        = number
  default     = 7
}
