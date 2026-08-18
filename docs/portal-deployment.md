# Manual deployment through Azure Portal

This guide produces the same comparison manually. Use the Bicep and PowerShell path in the repository when repeatability is the priority. Do not add tenant IDs, subscription IDs, credentials, or other environment-specific values to this document.

## 1. Prepare the environment

1. In Azure Portal, select the target subscription and create the resource group in `Central US`.
2. Keep a short unique prefix available for all names.
3. Open Cloud Shell with PowerShell and select the same subscription:

```powershell
az account set --subscription <subscription-id>
az group create --name <resource-group> --location centralus
```

## 2. Create App Service origins

1. Create a Linux Basic B1 App Service Plan and Web App in `Central US`.
2. Create a second Linux Basic B1 App Service Plan and Web App in `North Central US`.
3. In each Web App, open **Settings > Environment variables** and add:
   - `REGION`: `Central US` or `North Central US`
   - `HEALTHY`: `true`
   - `WEBSITE_RUN_FROM_PACKAGE`: `1`
4. Use **Deployment Center** or a ZIP deployment to publish `app/server.js` as the app package. The app exposes `/`, `/region`, and `/health`.
5. Test `https://<webapp>.azurewebsites.net/health` for both regions.

## 3. Create AKS origins

Create a small AKS cluster in each region with one node. Use public cluster networking for this demonstration. A production topology would use a hardened ingress design instead.

1. In the portal, create the Central US cluster with a one-node `Standard_B2s` system pool and Azure CNI Overlay.
2. Repeat in North Central US.
3. Create a Basic ACR in either region. Keep the admin user disabled.
4. Create both AKS clusters before assigning registry permissions. For each cluster, open **Properties > Identity** and identify the **kubelet identity** object, not only the cluster control-plane identity.
5. On the ACR, open **Access control (IAM) > Add role assignment**, select **AcrPull**, and assign it to each cluster's kubelet managed identity. The kubelet identity is the identity used by the node to pull the image.

## 4. Build the image and apply Kubernetes manifests in Cloud Shell

Use Cloud Shell to clone this repository, build the image in ACR, substitute manifest placeholders, and apply the workload. Repeat the commands for both clusters.

```powershell
git clone <repository-url>
Set-Location FD_TM_Resiliency_Demo

$rg = '<resource-group>'
$acr = '<acr-name>'
$image = "$acr.azurecr.io/fd-tm-demo:v1"
az acr build --registry $acr --image fd-tm-demo:v1 --file app/Dockerfile app

$appName = '<demo-app-name>'
$cluster = '<aks-centralus-name>'
$dnsLabel = '<prefix>-cu'
az aks get-credentials --resource-group $rg --name $cluster --overwrite-existing
$manifest = (Get-Content k8s/deployment.yaml -Raw).Replace('__APP_NAME__', $appName).Replace('__IMAGE__', $image).Replace('__REGION__', 'Central US').Replace('__DNS_LABEL__', $dnsLabel)
$manifest | kubectl apply -f -
kubectl rollout status deployment/$appName --timeout=180s
kubectl get service $appName
```

For North Central US, use its cluster name, DNS label `<prefix>-ncu`, and region text `North Central US`. Wait until each `LoadBalancer` service has an external address. Its public FQDN is `<dns-label>.<region>.cloudapp.azure.com`.

## 5. Create Front Door Standard

Create Front Door only after both App Services are responding and both AKS `LoadBalancer` services have an external FQDN. This ordering avoids creating origins with incomplete targets or routes before their origin groups contain enabled origins.

1. Create one Front Door Standard profile.
2. Create an App Service endpoint and an origin group with the two Web App hostnames.
3. Set App Service origin priority to `1` for Central US and `2` for North Central US. Configure HTTPS `GET /health` probes and a route matching `/*`.
4. Create an AKS endpoint and a separate origin group using the two public AKS FQDNs.
5. Set the same priorities. Configure HTTP `GET /health` probes and a route matching `/*`.
6. Save the generated endpoint hostnames and confirm each endpoint returns the Central US response. If a route is still provisioning, wait until its portal status is **Succeeded** before testing.

## 6. Create Traffic Manager profiles

1. Create a profile named for App Service with routing method **Priority**, DNS TTL `30`, and HTTPS monitor path `/health`.
2. Add the Central US Web App as priority `1` and North Central US Web App as priority `2`.
3. Create a second profile named for AKS with **Priority**, TTL `30`, and HTTP monitor path `/health`.
4. Add the two AKS public FQDNs as external endpoints at priorities `1` and `2`.
5. Test DNS response in Cloud Shell:

```powershell
Resolve-DnsName <traffic-manager-fqdn> -Type A
```

To demonstrate App Service through a browser without a custom domain, resolve the App Service Traffic Manager profile by CNAME:

```powershell
Resolve-DnsName <TM_APP_FQDN> -Type CNAME
```

Open the returned `NameHost` value, such as `<app-primary>.azurewebsites.net`, in the browser. Do not expect `<TM_APP_FQDN>` itself to render the App Service application: Traffic Manager is DNS-based and does not rewrite the HTTP `Host` header, so the App Service may return `404 Site Not Found` for the unbound `trafficmanager.net` hostname. After failover, repeat the CNAME lookup and open the new native Web App hostname, such as `<app-secondary>.azurewebsites.net`.

For AKS, open `http://<TM_AKS_FQDN>` directly in the browser. The public Kubernetes LoadBalancer accepts the generated Traffic Manager hostname, so the response should show the selected region.

## 7. Demonstrate failover and restore

For App Service, in **Overview**, select the Central US Web App and choose **Stop**. For a logical health failure instead, change `HEALTHY` to `false` under **Environment variables** and restart the app.

For AKS, in Cloud Shell, use the same value configured as `DEMO_APP_NAME`:

```powershell
kubectl scale deployment/<demo-app-name> --replicas=0
```

Repeat Front Door and Traffic Manager tests after health checks detect the failure. Restore the apps by starting the Web App or setting `HEALTHY=true`; restore AKS with:

```powershell
kubectl scale deployment/<demo-app-name> --replicas=1
```

## 8. Cleanup

Delete the resource group from the portal. Traffic Manager and Front Door are global resources but are removed when they are deployed in the same resource group.