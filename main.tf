resource "azurerm_resource_group" "rg" {
  name     = "aks-resource-group"
  location = var.region
}

# Create the VNET
resource "azurerm_virtual_network" "leenet-vnet" {
  name                = "${var.region}-${var.environment}-${var.app_name}-vnet"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags = {
    environment = var.environment
  }
}

# Create a Gateway Subnet
resource "azurerm_subnet" "leenet-gateway-subnet" {
  count                = var.vpn_instance_count
  name                 = "GatewaySubnet" # do not rename
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.leenet-vnet.name
  address_prefixes     = ["10.10.0.0/24"]
}

resource "azurerm_subnet" "aks-subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.leenet-vnet.name
  address_prefixes     = ["10.10.16.0/20"]
  service_endpoints    = ["Microsoft.ContainerRegistry"]
}

resource "azuread_group" "aks-admin-group" {
  display_name     = "AKS-Aadmins"
  security_enabled = true
}

resource "azurerm_kubernetes_cluster" "aks" {
  count               = var.aks_instance_count
  name                = "aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.prefix
  default_node_pool {
    name                  = "default"
    vnet_subnet_id        = azurerm_subnet.aks-subnet.id
    type                  = "VirtualMachineScaleSets"
    auto_scaling_enabled   = true
#    enable_node_public_ip = false
    max_count             = 1
    min_count             = 1
    os_disk_size_gb       = 256
    vm_size               = "Standard_D2_v2"
    max_pods              = 250
    node_labels = {
      role = "master"
    }
  }
  azure_active_directory_role_based_access_control {
#    managed                = true
    admin_group_object_ids = [azuread_group.aks-admin-group.object_id]
    azure_rbac_enabled     = true
  }
  identity {
    type = "SystemAssigned"
  }
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
  }

  azure_policy_enabled             = true
  http_application_routing_enabled = false
}

resource "azurerm_kubernetes_cluster_node_pool" "worker" {
  name                  = "worker"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks[0].id
  vm_size               = "Standard_DS2_v2"
  vnet_subnet_id        = azurerm_subnet.aks-subnet.id
  max_count             = 1
  min_count             = 1
  auto_scaling_enabled   = true
  node_labels = {
    role = "worker"
  }
}

resource "azurerm_container_registry" "leenet-registry" {
  count               = var.aks_instance_count
  name                = "leenetRegistry"
  admin_enabled       = true
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  depends_on          = [azurerm_kubernetes_cluster.aks]

}

resource "azurerm_role_assignment" "acrpull" {
  count                            = var.aks_instance_count
  principal_id                     = azurerm_kubernetes_cluster.aks[0].kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.leenet-registry[0].id
  skip_service_principal_aad_check = true
  depends_on                       = [azurerm_container_registry.leenet-registry]
}

###################Install Istio (Service Mesh) #######################################
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

data "azurerm_subscription" "current" {

}

resource "local_file" "kube_config" {
  count    = var.aks_instance_count
  content  = azurerm_kubernetes_cluster.aks[0].kube_admin_config_raw
  filename = "kube-cluster/config"
}


resource "null_resource" "set-kube-config" {
  count = var.aks_instance_count
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    working_dir = path.module
    command     = "az aks get-credentials -n ${azurerm_kubernetes_cluster.aks[0].name} -g ${azurerm_resource_group.rg.name} --file kube-cluster/${azurerm_kubernetes_cluster.aks[0].name} --admin --overwrite-existing"
  }
  depends_on = [local_file.kube_config]
}


resource "kubernetes_namespace" "istio_system" {
  count    = var.aks_instance_count
  provider = kubernetes
  metadata {
    name = "istio-system"
  }
}

resource "kubernetes_secret" "grafana" {
  count    = var.aks_instance_count
  provider = kubernetes
  metadata {
    name      = "grafana"
    namespace = "istio-system"
    labels = {
      app = "grafana"
    }
  }
  data = {
    username   = "admin"
    passphrase = random_password.password.result
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace.istio_system]
}

resource "kubernetes_secret" "kiali" {
  count    = var.aks_instance_count
  provider = kubernetes
  metadata {
    name      = "kiali"
    namespace = "istio-system"
    labels = {
      app = "kiali"
    }
  }
  data = {
    username   = "admin"
    passphrase = random_password.password.result
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace.istio_system]
}

resource "kubernetes_secret" "cert-manager-route53-secret" {
  metadata {
    name      = "route53-secret"
    namespace = "cert-manager"
  }

  data = {
    secret-access-key = var.route53-secret
  }

  type       = "Opaque"
  depends_on = [kubernetes_namespace.istio_system]
}

resource "kubernetes_secret" "istio-system-route53-secret" {
  metadata {
    name      = "route53-secret"
    namespace = "istio-system"
  }

  data = {
    secret-access-key = var.route53-secret
  }

  type       = "Opaque"
  depends_on = [kubernetes_namespace.istio_system]
}


resource "local_file" "istio-config" {
  count = var.aks_instance_count
  content = templatefile("${path.module}/istio-aks.tmpl", {
    enableGrafana = true
    enableKiali   = true
    enableTracing = true
  })
  filename = ".istio/istio-aks.yaml"
}

resource "null_resource" "istio" {
  count = var.aks_instance_count
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command     = "istioctl manifest apply -f .istio/istio-aks.yaml --skip-confirmation --kubeconfig kube-cluster/${azurerm_kubernetes_cluster.aks[0].name}"
    working_dir = path.module
  }
  depends_on = [kubernetes_secret.grafana, kubernetes_secret.kiali, local_file.istio-config]
}


module "cert_manager" {
  count  = var.aks_instance_count
  source = "terraform-iaac/cert-manager/kubernetes"

  cluster_issuer_email                   = "rleecharlie@gmail.com"
  cluster_issuer_name                    = "cert-manager-global"
  cluster_issuer_private_key_secret_name = "lets-encrypt-production-dns"
  depends_on                             = [null_resource.istio]
}

################### Deploy yaml with gateway  #######################################

// kubectl provider can be installed from here - https://gavinbunney.github.io/terraform-provider-kubectl/docs/provider.html 
data "kubectl_filename_list" "manifests" {
  count   = var.aks_instance_count
  pattern = "samples/yaml/*.yaml"
}

resource "kubectl_manifest" "yaml" {
  count      = var.aks_instance_count > 0 ? length(data.kubectl_filename_list.manifests[0].matches) : 0
  yaml_body  = var.aks_instance_count > 0 ? file(element(data.kubectl_filename_list.manifests[0].matches, count.index)) : ""
  depends_on = [helm_release.leenet-ingress]
}
