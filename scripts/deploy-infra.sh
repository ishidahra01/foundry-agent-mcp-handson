#!/bin/bash
# Deploy infrastructure using Bicep templates

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Foundry MCP Handson - Infrastructure Deployment ===${NC}\n"

# Check if required tools are installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed${NC}"
    echo "Please install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}Not logged in to Azure. Running 'az login'...${NC}"
    az login
fi

# Get current subscription
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo -e "Using subscription: ${GREEN}${SUBSCRIPTION_ID}${NC}\n"

# Prompt for parameters if not set
read -p "Enter Resource Group Name [rg-foundry-mcp-handson]: " RG_NAME
RG_NAME=${RG_NAME:-rg-foundry-mcp-handson}

read -p "Enter Location [japaneast]: " LOCATION
LOCATION=${LOCATION:-japaneast}

read -p "Enter Azure AD Tenant ID: " TENANT_ID
if [ -z "$TENANT_ID" ]; then
    TENANT_ID=$(az account show --query tenantId -o tsv)
    echo -e "Using current tenant: ${GREEN}${TENANT_ID}${NC}"
fi

read -p "Enter Azure AD Client ID (Application ID): " CLIENT_ID
if [ -z "$CLIENT_ID" ]; then
    echo -e "${RED}Error: Client ID is required${NC}"
    exit 1
fi

read -p "Enter APIM Publisher Email: " PUBLISHER_EMAIL
if [ -z "$PUBLISHER_EMAIL" ]; then
    echo -e "${RED}Error: Publisher email is required${NC}"
    exit 1
fi

read -p "Enter APIM Publisher Name [MCP Handson]: " PUBLISHER_NAME
PUBLISHER_NAME=${PUBLISHER_NAME:-MCP Handson}

# Deploy infrastructure
echo -e "\n${GREEN}Deploying infrastructure...${NC}"
echo "This may take 20-30 minutes for APIM provisioning..."

DEPLOYMENT_NAME="foundry-mcp-$(date +%Y%m%d-%H%M%S)"

az deployment sub create \
  --name "$DEPLOYMENT_NAME" \
  --location "$LOCATION" \
  --template-file infra/main.bicep \
  --parameters \
    resourceGroupName="$RG_NAME" \
    location="$LOCATION" \
    tenantId="$TENANT_ID" \
    clientId="$CLIENT_ID" \
    publisherEmail="$PUBLISHER_EMAIL" \
    publisherName="$PUBLISHER_NAME"

# Get outputs
echo -e "\n${GREEN}Getting deployment outputs...${NC}"

OUTPUTS=$(az deployment sub show \
  --name "$DEPLOYMENT_NAME" \
  --query properties.outputs \
  -o json)

APIM_NAME=$(echo "$OUTPUTS" | jq -r '.apimName.value')
APIM_URL=$(echo "$OUTPUTS" | jq -r '.apimGatewayUrl.value')
FUNCTION_NAME=$(echo "$OUTPUTS" | jq -r '.functionAppName.value')
FUNCTION_URL=$(echo "$OUTPUTS" | jq -r '.functionAppUrl.value')
WEBAPP_NAME=$(echo "$OUTPUTS" | jq -r '.webAppName.value')
WEBAPP_URL=$(echo "$OUTPUTS" | jq -r '.webAppUrl.value')

echo -e "\n${GREEN}=== Deployment Complete ===${NC}\n"
echo "Resource Group: $RG_NAME"
echo "APIM Name: $APIM_NAME"
echo "APIM URL: $APIM_URL"
echo "Function App: $FUNCTION_NAME"
echo "Function URL: $FUNCTION_URL"
echo "Web App: $WEBAPP_NAME"
echo "Web App URL: $WEBAPP_URL"

# Save outputs to file
cat > deployment-outputs.json <<EOF
{
  "resourceGroup": "$RG_NAME",
  "apimName": "$APIM_NAME",
  "apimUrl": "$APIM_URL",
  "apimMcpEndpoint": "$APIM_URL/mcp/filter",
  "functionName": "$FUNCTION_NAME",
  "functionUrl": "$FUNCTION_URL",
  "webAppName": "$WEBAPP_NAME",
  "webAppUrl": "$WEBAPP_URL",
  "tenantId": "$TENANT_ID",
  "clientId": "$CLIENT_ID"
}
EOF

echo -e "\n${GREEN}✓ Outputs saved to: deployment-outputs.json${NC}"

echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Deploy the Function App: ./scripts/deploy-function.sh"
echo "2. Configure and deploy the Web App: ./scripts/deploy-webapp.sh"
echo "3. Create the Foundry Agent: python scripts/create_agent.py"
echo "4. Test the application"
