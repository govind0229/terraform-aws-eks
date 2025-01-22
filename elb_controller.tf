###########################################################################################################################
# Create AWS Load Balancer Controller IAM role and policies
###########################################################################################################################

data "http" "load_balancer_controller_policies" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json"
}

locals {
  policy_data = data.http.load_balancer_controller_policies.response_body
}

resource "aws_iam_role" "nlb_service_account" {
  name               = "aws-load-balancer-controller-sa-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.nlb_sa_role_Principal.json
}

resource "aws_iam_policy" "nlb_controller_policy" {
  name        = "nlb-controller-policy-${var.environment}"
  description = "AWS Load Balancer Controller Policy"
  policy      = local.policy_data
}

resource "aws_iam_role_policy_attachment" "nlb_controller_attachment" {
  policy_arn = aws_iam_policy.nlb_controller_policy.arn
  role       = aws_iam_role.nlb_service_account.name

  depends_on = [
    aws_iam_role.nlb_service_account,
    aws_iam_policy.nlb_controller_policy
  ]
}

###########################################################################################################################
# Add AWS Load Balancer Controller Helm Chart to the EKS cluster
###########################################################################################################################

resource "helm_release" "aws_load_balancer_controller" {
  name       = "helm-lb-install"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.4.8"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.this[0].id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = aws_iam_role.nlb_service_account.name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.nlb_service_account.arn
  }

  depends_on = [
    aws_eks_cluster.this,
    aws_eks_node_group.this,
    aws_iam_role_policy_attachment.nlb_controller_attachment,
    aws_eks_addon.this
  ]
}

###########################################################################################################################
# Resource: Kubernetes Ingress Class
###########################################################################################################################

resource "kubernetes_ingress_class_v1" "ingress_class_default" {
  depends_on = [helm_release.aws_load_balancer_controller]

  metadata {
    name = "aws-ingress-class"
    annotations = {
      "ingressclass.kubernetes.io/is-default-class" = "true"
    }
  }

  spec {
    controller = "ingress.k8s.aws/alb"
  }
}
