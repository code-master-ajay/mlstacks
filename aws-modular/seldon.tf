# using the seldon module for creating a 
# seldon + istio deployment
module "seldon" {
  source = "../modules/seldon-module"

  count = var.enable_seldon ? 1 : 0

  # run only after the eks cluster and istio are set up
  depends_on = [
    module.eks,
    null_resource.configure-local-kubectl,
    module.istio
  ]

  # details about the seldon deployment
  chart_version = local.seldon.version
}

# the namespace where zenml will deploy seldon models
resource "kubernetes_namespace" "seldon-workloads" {

  count = var.enable_seldon ? 1 : 0

  metadata {
    name = local.seldon.workloads_namespace
  }
}

# add role to allow kubeflow to access seldon
#
# NOTE: the seldon zenml model deployer pipeline steps need to be able to create
# secrets, serviceaccounts, and Seldon deployments in the namespace where it
# will deploy models
resource "kubernetes_cluster_role_v1" "seldon" {

  count = var.enable_seldon ? 1 : 0

  metadata {
    name = "seldon-workloads"
    labels = {
      app = "zenml"
    }
  }

  rule {
    api_groups = ["machinelearning.seldon.io", ""]
    resources  = ["seldondeployments", "secrets", "serviceaccounts"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  depends_on = [
    module.seldon,
  ]
}

# assign role to kubeflow pipeline runner
resource "kubernetes_role_binding_v1" "kubeflow-seldon" {

  count = (var.enable_kubeflow && var.enable_seldon) ? 1 : 0

  metadata {
    name      = "kubeflow-seldon"
    namespace = kubernetes_namespace.seldon-workloads[0].metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.seldon[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "pipeline-runner"
    namespace = "kubeflow"
  }

  depends_on = [
    module.kubeflow-pipelines,
  ]
}

# assign role to kubernetes pipeline runner
resource "kubernetes_role_binding_v1" "k8s-seldon" {

  count = var.enable_seldon ? 1 : 0

  metadata {
    name      = "k8s-seldon"
    namespace = kubernetes_namespace.seldon-workloads[0].metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.seldon[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = kubernetes_namespace.k8s-workloads[0].metadata[0].name
  }
}

