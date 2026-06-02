resource "kubernetes_namespace" "jenkins" {
  metadata { name = "jenkins" }
}

resource "kubernetes_namespace" "sonarqube" {
  metadata { name = "sonarqube" }
}

resource "kubernetes_namespace" "dev" {
  metadata { name = "dev" }
}

resource "kubernetes_namespace" "monitoring" {
  metadata { name = "monitoring" }
}

resource "kubernetes_service_account" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }
}

resource "kubernetes_cluster_role" "jenkins" {
  metadata { name = "jenkins-cluster-role" }

  rule {
    api_groups = ["*"]
    resources  = ["pods", "pods/exec", "pods/log", "deployments", "services", "configmaps", "secrets", "namespaces", "replicasets", "jobs"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "statefulsets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_cluster_role_binding" "jenkins" {
  metadata { name = "jenkins-cluster-role-binding" }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.jenkins.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.jenkins.metadata[0].name
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }
}
