# MCP Server (Azure Functions)

This directory contains the MCP (Model Context Protocol) server implementation as an Azure Function.

## Features

- Implements MCP protocol for tool listing and execution
- `get_weather` tool that returns weather information
- User-specific responses based on `X-EndUser-Id` header:
  - Even user ID hash → Temperature in Celsius
  - Odd user ID hash → Temperature in Fahrenheit

## Local Development

1. Install Azure Functions Core Tools
2. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Run locally:
   ```bash
   func start
   ```

## Deployment

Deploy to Azure Functions:
```bash
func azure functionapp publish <function-app-name>
```
