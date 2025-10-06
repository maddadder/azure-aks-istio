
resource "helm_release" "my-kubernetes-dashboard" {
  count = var.aks_instance_count
  name  = "my-kubernetes-dashboard"

  repository = "https://kubernetes.github.io/dashboard/"
  chart      = "kubernetes-dashboard"
  version      = "2.8.3"
  namespace  = "default"

  values = [
    file("${abspath(path.root)}/charts/my-kubernetes-dashboard/values.yaml")
  ]
  depends_on = [module.cert_manager]
}


resource "helm_release" "leenet-ingress" {
  namespace  = "istio-system"
  name       = "leenet-ingress"
  chart      = "${abspath(path.root)}/charts/leenet-ingress"
  depends_on = [module.cert_manager, kubernetes_secret.istio-system-route53-secret]
}


resource "helm_release" "shopstr" {
  namespace  = "default"
  name       = "shopstr"
  chart      = "${abspath(path.root)}/charts/shopstr"
  depends_on = [module.cert_manager, kubernetes_secret.istio-system-route53-secret]
}
