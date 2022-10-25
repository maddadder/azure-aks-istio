#  Setup terraform

1. Docs are from https://learnk8s.io/terraform-aks
2. cd C:\git\azure-aks-istio
3. install https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
```
az login
```
4. install terraform (run as admin)
```
choco install terraform
```
5. in mingw64, get the credentials:
```
az account list | grep -oP '(?<="id": ")[^"]*'
2acc8a84-6261-48be-a589-5b6983f616ea
```
6. In a normal cmd window run:
```
az account set --subscription="2acc8a84-6261-48be-a589-5b6983f616ea"
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/2acc8a84-6261-48be-a589-5b6983f616ea"
{
  "appId": "00000000-0000-0000-0000-000000000000",
  "displayName": "azure-cli-2021-02-13-20-01-37",
  "name": "http://azure-cli-2021-02-13-20-01-37",
  "password": "0000-0000-0000-0000-000000000000",
  "tenant": "00000000-0000-0000-0000-000000000000"
}
```
7. Install istioctl from https://istio.io/latest/docs/setup/getting-started/#download. I downloaded istioctl and put it in `C:\ProgramData\chocolatey\bin\`
8. If you are using neon (https://github.com/nforgeio/neonSDK) for password management, run the following command to setup your password `neon tool password set leenet-devops`. Then setup your vault by running from this path: .\azure-aks-istio `neon tool vault create terraform_env.txt leenet-devops`. If you already have a vault setup then type `neon tool vault edit terraform_env.txt` and paste in the following. The terraform provider will know how to read those environment variables. 
```
set ARM_CLIENT_ID=<insert the appId from above>
set ARM_SUBSCRIPTION_ID=<insert your subscription id>
set ARM_TENANT_ID=<insert the tenant from above>
set ARM_CLIENT_SECRET=<insert the password from above>
```
9. Open your environment variables from the vault via `neon tool vault edit terraform_env.txt` and paste in the contents from Notepad into your terminal to set your environment variables.
10. Follow these instructions: https://stackoverflow.com/questions/70851465/azure-ad-group-authorization-requestdenied-insufficient-privileges-to-complet
11. Rename your kube-cluster folder to kube-cluster.current so that you will only see what is imported in lens and so that if you have any other cluster setup it won't try and apply to your current k8s cluster
12. Run the following from .\azure-aks-istio `terraform init` if you haven't ran init yet, then:
```
terraform plan
terraform apply
```
13. You may have to run `terraform apply` twice
14. Install Lens (https://k8slens.dev/)
15. In Lens, File => Add Cluster, and paste in the `kubeconfig` file that was generated when you ran terraform apply
16. In Lens: get the external ip via `kubectl get svc istio-ingressgateway -n istio-system`
```
NAME                   TYPE           CLUSTER-IP   EXTERNAL-IP    PORT(S)                                      AGE
istio-ingressgateway   LoadBalancer   10.0.21.44   20.252.13.28   15021:32186/TCP,80:31502/TCP,443:30900/TCP   26m
```
17. Setup your hosts file to point a dns name to the external ip listed in the prior step, e.g. `20.252.13.28	leenet.link`
18. Navigate to http://leenet.link/productpage. If the page does not load then check to make sure all the deployments were actually deployed, make sure the pods are running, etc

# azure-aks-istio

https://github.com/hashicorp/terraform-provider-kubernetes/blob/main/_examples/aks/