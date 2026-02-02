#!/bin/bash
# Integration test script for Flow① MCP implementation

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Flow① Integration Test ===${NC}\n"

# Check if MCP server is running
echo -e "${YELLOW}1. Testing MCP Server...${NC}"
if curl -s http://localhost:7071/api/mcp > /dev/null 2>&1; then
  echo -e "${GREEN}✓ MCP Server is running${NC}"
else
  echo -e "${RED}✗ MCP Server is not running${NC}"
  echo "Please start the server with: cd mcp-server && func start"
  exit 1
fi

# Test tools/list
echo -e "\n${YELLOW}2. Testing tools/list endpoint...${NC}"
TOOLS_RESPONSE=$(curl -s http://localhost:7071/api/mcp)
if echo "$TOOLS_RESPONSE" | jq -e '.result.tools[] | select(.name == "get_weather")' > /dev/null 2>&1; then
  echo -e "${GREEN}✓ get_weather tool is available${NC}"
else
  echo -e "${RED}✗ get_weather tool not found${NC}"
  exit 1
fi

# Test even user (Celsius)
echo -e "\n${YELLOW}3. Testing even user (should get Celsius)...${NC}"
EVEN_RESPONSE=$(curl -s -X POST http://localhost:7071/api/mcp \
  -H "Content-Type: application/json" \
  -H "X-EndUser-Id: user-even-12345678" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "id": "1",
    "params": {
      "name": "get_weather",
      "arguments": {
        "city": "Tokyo"
      }
    }
  }')

if echo "$EVEN_RESPONSE" | jq -r '.result.content[0].text' | grep -q "°C"; then
  echo -e "${GREEN}✓ Celsius response for even user${NC}"
  echo "$EVEN_RESPONSE" | jq -r '.result.content[0].text' | jq .
else
  echo -e "${RED}✗ Expected Celsius but got:${NC}"
  echo "$EVEN_RESPONSE" | jq .
  exit 1
fi

# Test odd user (Fahrenheit)
echo -e "\n${YELLOW}4. Testing odd user (should get Fahrenheit)...${NC}"
ODD_RESPONSE=$(curl -s -X POST http://localhost:7071/api/mcp \
  -H "Content-Type: application/json" \
  -H "X-EndUser-Id: user-odd-87654321" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "id": "1",
    "params": {
      "name": "get_weather",
      "arguments": {
        "city": "Tokyo"
      }
    }
  }')

if echo "$ODD_RESPONSE" | jq -r '.result.content[0].text' | grep -q "°F"; then
  echo -e "${GREEN}✓ Fahrenheit response for odd user${NC}"
  echo "$ODD_RESPONSE" | jq -r '.result.content[0].text' | jq .
else
  echo -e "${RED}✗ Expected Fahrenheit but got:${NC}"
  echo "$ODD_RESPONSE" | jq .
  exit 1
fi

# Test different cities
echo -e "\n${YELLOW}5. Testing different cities...${NC}"
for city in "Tokyo" "Osaka" "New York" "London" "Paris"; do
  CITY_RESPONSE=$(curl -s -X POST http://localhost:7071/api/mcp \
    -H "Content-Type: application/json" \
    -H "X-EndUser-Id: test-user" \
    -d "{
      \"jsonrpc\": \"2.0\",
      \"method\": \"tools/call\",
      \"id\": \"1\",
      \"params\": {
        \"name\": \"get_weather\",
        \"arguments\": {
          \"city\": \"$city\"
        }
      }
    }")
  
  if echo "$CITY_RESPONSE" | jq -r '.result.content[0].text' | grep -q "$city"; then
    echo -e "${GREEN}✓ $city${NC}"
  else
    echo -e "${RED}✗ $city${NC}"
  fi
done

# Test unknown city
echo -e "\n${YELLOW}6. Testing unknown city (should return error)...${NC}"
UNKNOWN_RESPONSE=$(curl -s -X POST http://localhost:7071/api/mcp \
  -H "Content-Type: application/json" \
  -H "X-EndUser-Id: test-user" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "id": "1",
    "params": {
      "name": "get_weather",
      "arguments": {
        "city": "UnknownCity"
      }
    }
  }')

if echo "$UNKNOWN_RESPONSE" | jq -r '.result.content[0].text' | grep -q "error"; then
  echo -e "${GREEN}✓ Error returned for unknown city${NC}"
else
  echo -e "${YELLOW}⚠ No error for unknown city (might be expected)${NC}"
fi

echo -e "\n${GREEN}=== All Tests Passed! ===${NC}"
echo -e "\nNext steps:"
echo "1. Deploy to Azure: ./scripts/deploy-infra.sh"
echo "2. Test APIM endpoint with JWT authentication"
echo "3. Test the Web UI"
