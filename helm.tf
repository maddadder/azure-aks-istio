
resource "helm_release" "my-kubernetes-dashboard" {
  count               = var.aks_instance_count
  name = "my-kubernetes-dashboard"

  repository = "https://kubernetes.github.io/dashboard/"
  chart      = "kubernetes-dashboard"
  namespace  = "default"

  set {
    name  = "service.externalPort"
    value = 9090
  }

  set {
    name  = "replicaCount"
    value = 1
  }

  set {
    name  = "rbac.clusterReadOnlyRole"
    value = "true"
  }

  set {
    name  = "extraArgs"
    value = "{--enable-insecure-login=true,--insecure-bind-address=0.0.0.0,--insecure-port=9090}"
  }

  set {
    name  = "protocolHttp"
    value = true
  }
  depends_on = [module.cert_manager]
}


resource "helm_release" "leenet-ingress" {
 name  = "leenet-ingress"
 chart = "${abspath(path.root)}/charts/leenet-ingress"
 depends_on = [module.cert_manager]
}

resource "helm_release" "couchbase-operator" {
 namespace  = "couchbase"
 create_namespace = true
 name  = "couchbase-operator"
 chart = "${abspath(path.root)}/charts/couchbase-operator"
 values = [
    file("${abspath(path.root)}/charts/couchbase-operator/values.leenet.yaml")
 ]
 depends_on = [helm_release.leenet-ingress]
}

resource "helm_release" "couchbase-cluster" {
 namespace  = "couchbase"
 name  = "couchbase-cluster"
 chart = "${abspath(path.root)}/charts/couchbase-cluster"
 depends_on = [helm_release.couchbase-operator]
}