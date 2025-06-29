provider "kubernetes" {
  config_path = "~/.kube/config"
}
 
provider "helm" {
  kubernetes  = {
    config_path = "~/.kube/config"
  }
}
 
data "aws_eks_cluster" "eks" {
  name = "demo-cluster"
}
 
data "aws_eks_cluster_auth" "eks" {
  name = "demo-cluster"
}
 
data "tls_certificate" "oidc_thumbprint" {
  url = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
}
 
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc_thumbprint.certificates[0].sha1_fingerprint]
  url             = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
}
 
resource "aws_iam_policy" "alb_controller_policy" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  path   = "/"
  policy = file("${path.module}/iam-policy.json")
}
 
resource "aws_iam_role" "alb_sa_role" {
  name = "AmazonEKSLoadBalancerControllerRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      },
      Action    = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}
 
resource "aws_iam_role_policy_attachment" "alb_sa_attach" {
  role       = aws_iam_role.alb_sa_role.name
  policy_arn = aws_iam_policy.alb_controller_policy.arn
}
 
resource "kubernetes_service_account" "alb_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_sa_role.arn
    }
  }
}
 
resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.1"
 
  timeout    = 500
  wait       = true
  force_update = true
 
  set = [
    {
      name  = "clusterName"
      value = "demo-cluster"
    },
    {
      name  = "region"
      value = "ap-south-1"
    },
    {
      name  = "vpcId"
      value = data.aws_eks_cluster.eks.vpc_config[0].vpc_id
    },
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = kubernetes_service_account.alb_sa.metadata[0].name
    },
     {
      name  = "replicaCount"
      value = "1"             # ✅ This forces only 1 pod to deploy
    }
  ]
 
  depends_on = [
    kubernetes_service_account.alb_sa
  ]
}
 