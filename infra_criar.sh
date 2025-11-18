#!/bin/bash
set -euo pipefail

# ---------- Variáveis (ajuste se quiser) ----------
resourceGroupNamex="rg_gscloud"
locationx="eastus"
vmnamex="vm_gscloud"
adminUserx="nyc_ju"
adminPasswordx="SenhaForte123!"
vmsizex="Standard_B1ms"
planSku="B1"

webAppName="WebAppGSCloud"
planName="${webAppName}-plan"

# Nome do storage (gera um nome único simples; ajuste se quiser)
STORAGE_ACCOUNT="stggscloud$(date +%s | sha256sum | head -c6)"

containerName="csvfiles"

# ------------- Início das operações -------------
echo "1) Criando Resource Group: $resourceGroupNamex (location: $locationx)"
az group create --name "$resourceGroupNamex" --location "$locationx"

echo "2) Criando VM: $vmnamex (tamanho: $vmsizex) - usuário: $adminUserx"
az vm create \
  --resource-group "$resourceGroupNamex" \
  --name "$vmnamex" \
  --image Ubuntu2204 \
  --size "$vmsizex" \
  --location "$locationx" \
  --admin-username "$adminUserx" \
  --admin-password "$adminPasswordx" \
  --public-ip-sku Standard

echo "3) Garantindo tamanho da VM (resize se necessário)"
az vm resize -g "$resourceGroupNamex" -n "$vmnamex" --size "$vmsizex" || true

echo "4) Criando App Service Plan: $planName (sku $planSku)"
az appservice plan create --name "$planName" --resource-group "$resourceGroupNamex" --location "$locationx" --is-linux --sku "$planSku"

echo "5) Criando WebApp: $webAppName (Python 3.12)"
az webapp create --resource-group "$resourceGroupNamex" --plan "$planName" --name "$webAppName" --runtime "PYTHON|3.12"

echo "6) Criando Storage Account: $STORAGE_ACCOUNT"
az storage account create --name "$STORAGE_ACCOUNT" --resource-group "$resourceGroupNamex" --location "$locationx" --sku Standard_LRS

echo "7) Recuperando chave do Storage"
STORAGE_KEY=$(az storage account keys list -g "$resourceGroupNamex" -n "$STORAGE_ACCOUNT" --query "[0].value" -o tsv)

echo "8) Criando container Blob: $containerName"
az storage container create --account-name "$STORAGE_ACCOUNT" --account-key "$STORAGE_KEY" --name "$containerName"

echo "9) Configurando appsettings do WebApp (variáveis de storage)"
az webapp config appsettings set --resource-group "$resourceGroupNamex" --name "$webAppName" --settings \
    AZURE_STORAGE_ACCOUNT="$STORAGE_ACCOUNT" \
    AZURE_STORAGE_KEY="$STORAGE_KEY" \
    CSV_CONTAINER="$containerName"

echo ""
echo "----- RESUMO -----"
echo "Resource Group: $resourceGroupNamex"
echo "Location: $locationx"
echo "VM: $vmnamex (user: $adminUserx)"
echo "WebApp: $webAppName"
echo "App Plan: $planName"
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Container: $containerName"
echo "------------------"
echo "Script finalizado com sucesso."
