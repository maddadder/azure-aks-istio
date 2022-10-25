provider "azurerm" {
  features {}
}
provider "kubernetes" {
  alias                  = "local"
  host                   = azurerm_kubernetes_cluster.aks.kube_admin_config.0.host
  client_certificate     = "${base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_certificate)}"
  client_key             = "${base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_key)}"
  cluster_ca_certificate = "${base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.cluster_ca_certificate)}"
}

provider "kubectl" {
  host                   = azurerm_kubernetes_cluster.aks.kube_admin_config.0.host
  client_certificate     = "${base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_certificate)}"
  client_key             = "${base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_key)}"
  cluster_ca_certificate = "${base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config.0.cluster_ca_certificate)}"
  config_path            = "./kube-cluster/aks"
  config_context         = "aks-admin"
}
