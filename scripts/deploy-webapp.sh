#!/bin/bash
# Deploy Web App

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Deploying Web App ===${NC}\n"

# Check if deployment outputs exist
if [ ! -f "deployment-outputs.json" ]; then
    echo -e "${RED}Error: deployment-outputs.json not found${NC}"
    echo "Please run ./scripts/deploy-infra.sh first"
    exit 1
fi

# Check if agent config exists
if [ ! -f "agent-config.json" ]; then
    echo -e "${YELLOW}Warning: agent-config.json not found${NC}"
    echo "Please run the agent creation script first:"
    echo "python scripts/create_agent.py --help"
fi

# Load configuration
WEBAPP_NAME=$(jq -r '.webAppName' deployment-outputs.json)
RG_NAME=$(jq -r '.resourceGroup' deployment-outputs.json)
WEBAPP_URL=$(jq -r '.webAppUrl' deployment-outputs.json)
TENANT_ID=$(jq -r '.tenantId' deployment-outputs.json)
CLIENT_ID=$(jq -r '.clientId' deployment-outputs.json)
APIM_MCP_ENDPOINT=$(jq -r '.apimMcpEndpoint' deployment-outputs.json)

echo "Web App: $WEBAPP_NAME"
echo "Resource Group: $RG_NAME"

# Prompt for Foundry configuration
read -p "Enter Azure Foundry Endpoint: " FOUNDRY_ENDPOINT
read -p "Enter Azure Foundry Key: " FOUNDRY_KEY
read -p "Enter Azure Foundry Agent ID: " AGENT_ID

if [ -z "$FOUNDRY_ENDPOINT" ] || [ -z "$FOUNDRY_KEY" ] || [ -z "$AGENT_ID" ]; then
    echo -e "${RED}Error: All Foundry configuration values are required${NC}"
    exit 1
fi

# Configure Web App settings
echo -e "\n${YELLOW}Configuring Web App settings...${NC}"

az webapp config appsettings set \
    -g "$RG_NAME" \
    -n "$WEBAPP_NAME" \
    --settings \
        NEXT_PUBLIC_AZURE_TENANT_ID="$TENANT_ID" \
        NEXT_PUBLIC_AZURE_CLIENT_ID="$CLIENT_ID" \
        NEXT_PUBLIC_REDIRECT_URI="$WEBAPP_URL" \
        AZURE_FOUNDRY_ENDPOINT="$FOUNDRY_ENDPOINT" \
        AZURE_FOUNDRY_KEY="$FOUNDRY_KEY" \
        AZURE_FOUNDRY_AGENT_ID="$AGENT_ID" \
        APIM_MCP_ENDPOINT="$APIM_MCP_ENDPOINT"

echo -e "${GREEN}✓ Web App settings configured${NC}"

# Build and deploy
echo -e "\n${YELLOW}Building Web App...${NC}"
cd webapp

# Install dependencies
npm install

# Build
npm run build

# Create zip for deployment
echo -e "\n${YELLOW}Creating deployment package...${NC}"
cd .next/standalone
zip -r ../../../webapp-deploy.zip . -x "node_modules/*"
cd ../..
zip -r ../webapp-deploy.zip .next/static public package.json
cd ..

# Deploy
echo -e "\n${YELLOW}Deploying to Azure...${NC}"
az webapp deployment source config-zip \
    -g "$RG_NAME" \
    -n "$WEBAPP_NAME" \
    --src webapp-deploy.zip

rm webapp-deploy.zip

echo -e "\n${GREEN}=== Deployment Complete ===${NC}"
echo -e "\nWeb App URL: ${GREEN}$WEBAPP_URL${NC}"
echo -e "\n${YELLOW}Note: It may take a few minutes for the app to start${NC}"
