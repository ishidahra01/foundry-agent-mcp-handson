#!/bin/bash
# Deploy Function App (MCP Server)

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Deploying Function App (MCP Server) ===${NC}\n"

# Check if deployment outputs exist
if [ ! -f "deployment-outputs.json" ]; then
    echo -e "${RED}Error: deployment-outputs.json not found${NC}"
    echo "Please run ./scripts/deploy-infra.sh first"
    exit 1
fi

# Load deployment outputs
FUNCTION_NAME=$(jq -r '.functionName' deployment-outputs.json)
RG_NAME=$(jq -r '.resourceGroup' deployment-outputs.json)

echo "Function App: $FUNCTION_NAME"
echo "Resource Group: $RG_NAME"

# Check if Azure Functions Core Tools is installed
if ! command -v func &> /dev/null; then
    echo -e "${YELLOW}Warning: Azure Functions Core Tools not found${NC}"
    echo "Attempting deployment using Azure CLI..."
    
    # Deploy using zip
    cd mcp-server
    zip -r ../function.zip . -x "*.pyc" -x "__pycache__/*"
    cd ..
    
    az functionapp deployment source config-zip \
        -g "$RG_NAME" \
        -n "$FUNCTION_NAME" \
        --src function.zip
    
    rm function.zip
else
    # Deploy using func tools
    cd mcp-server
    func azure functionapp publish "$FUNCTION_NAME" --python
    cd ..
fi

echo -e "\n${GREEN}✓ Function App deployed successfully${NC}"

# Get function key
echo -e "\n${YELLOW}Retrieving function key...${NC}"
FUNCTION_KEY=$(az functionapp keys list \
    -g "$RG_NAME" \
    -n "$FUNCTION_NAME" \
    --query "functionKeys.default" \
    -o tsv)

if [ ! -z "$FUNCTION_KEY" ]; then
    # Update APIM named value with function key
    APIM_NAME=$(jq -r '.apimName' deployment-outputs.json)
    
    echo "Updating APIM with function key..."
    az apim nv update \
        -g "$RG_NAME" \
        -n "$APIM_NAME" \
        --named-value-id "function-key" \
        --value "$FUNCTION_KEY" \
        --secret true
    
    echo -e "${GREEN}✓ APIM updated with function key${NC}"
fi

echo -e "\n${GREEN}=== Deployment Complete ===${NC}"
echo -e "\nTest the function:"
echo "curl \"https://${FUNCTION_NAME}.azurewebsites.net/api/mcp?code=${FUNCTION_KEY}\""
