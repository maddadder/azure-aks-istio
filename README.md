#  Setup terraform

1. Docs are from https://learnk8s.io/terraform-aks and 
1. Follow the steps before creating the secret access key in https://voyagermesh.com/docs/v2021.10.18/guides/cert-manager/dns01_challenge/aws-route53/. 
> This includes Go to IAM page and:
> 1. Creating the user
> 2. Click on next and select Attach existing policies directly and click on Create Policy
> 3. Click on json and paste this and click Review Policy
> 4. Name the policy and click Create policy, 
> 5. Instead of `Create a secret with the Secret Access Key`, just get the secret and paste it in the `terraform.tfvars` file under `route53-secret`.
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
12. Run the following from .\azure-aks-istio `pwsh -f generate-certificate.ps1`
13. Go into azure and create a custom role via Access your subscription, IAM, Add, Custom Role, paste in the json in the json tab
```
{
    "properties": {
        "roleName": "role_assignment_write_delete",
        "description": "Allow role to write and delete roles in this subscription",
        "assignableScopes": [
            "/subscriptions/<your-subscription-id>"
        ],
        "permissions": [
            {
                "actions": [
                    "Microsoft.Authorization/roleAssignments/write",
                    "Microsoft.Authorization/roleAssignments/delete"
                ],
                "notActions": [],
                "dataActions": [],
                "notDataActions": []
            }
        ]
    }
}
```
14. Add, Role Assignment, choose role role_assignment_write_delete, add members, search fore azure-cli, add the assignment
15. Run the following from .\azure-aks-istio `terraform init` if you haven't ran init yet, either rename terraform-example.tfvars to terraform.tfvars or use the -var-file parameter:
```
terraform plan -var-file="terraform-example.tfvars"
terraform apply -var-file="terraform-example.tfvars"
```
16. Open your environment variables from the vault via `neon tool vault edit terraform_env.txt` and paste in the contents of the secret that's in the format: `kubectl create secret generic -n istio-system route53-secret --from-literal=secret-access-key="YOUR_ACCESS_KEY_SECRET"`
17. Run terraform apply again, however, some of the dependencies need you to run steps 24) Push images to the registry before terraform apply will complete successfully
18. Run `kubectl get Issuers,ClusterIssuers,Certificates,CertificateRequests,Orders,Challenges --all-namespaces` to get the status of the tls certificates. Once valid, you should be able to navigate to https://leenet.link and get a valid page. 

19. Install Lens (https://k8slens.dev/)
20. In Lens, File => Add Cluster, and paste in the `kubeconfig` file that was generated when you ran terraform apply
21. In Lens: get the external ip via `kubectl get svc istio-ingressgateway -n istio-system`
```
NAME                   TYPE           CLUSTER-IP   EXTERNAL-IP    PORT(S)                                      AGE
istio-ingressgateway   LoadBalancer   10.0.21.44   20.252.13.28   15021:32186/TCP,80:31502/TCP,443:30900/TCP   26m
```
22. Setup your hosts file to point a dns name to the external ip listed in the prior step, e.g. `20.252.13.28	leenet.link`
23. Navigate to http://leenet.link. If the page does not load then check to make sure all the deployments were actually deployed, make sure the pods are running, etc
24. Push images to the registry
```
docker login leenetregistry.azurecr.io  # You can get the login URI and credentials from Access keys blade in the azure portal
docker pull registry.k8s.io/e2e-test-images/jessie-dnsutils:1.3
docker tag registry.k8s.io/e2e-test-images/jessie-dnsutils:1.3 leenetregistry.azurecr.io/jessie-dnsutils:1.3
docker push leenetregistry.azurecr.io/jessie-dnsutils:1.3
```
25. Create the image pull secrets. For the `docker-password`, use the same credentials you used for docker login
```
kubectl create secret docker-registry leenet-registry --namespace default --docker-server=leenetregistry.azurecr.io --docker-username=leenetRegistry --docker-password=<service-principal-password>
```
26. Log into the couchbase cluster at `https://couchbase.leenet.link` and change the default password. Then go into the `my-couchbase` secret in the couchbase namespace and update it there too.
# azure-aks-istio

https://github.com/hashicorp/terraform-provider-kubernetes/blob/main/_examples/aks/


## Troubleshooting
1. To update a chart you can use Lens and run `helm list --namespace yournamespace` to find the chart and `helm uninstall --namespace yournamespace` and then run `terraform apply` to update the chart. It doesn't seem like terraform will reapply a chart once it's been installed.