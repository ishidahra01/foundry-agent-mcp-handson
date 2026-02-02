#!/usr/bin/env python3
"""
Script to create and configure Azure AI Foundry Project and Agent
with MCP tool integration for Flow①
"""

import os
import sys
import json
import argparse
from typing import Dict, Any

try:
    from azure.ai.projects import AIProjectClient
    from azure.identity import DefaultAzureCredential
    from azure.core.credentials import AzureKeyCredential
except ImportError:
    print("Error: Required packages not installed.")
    print("Please run: pip install azure-ai-projects azure-identity")
    sys.exit(1)


def create_foundry_agent(
    project_endpoint: str,
    project_key: str,
    apim_mcp_endpoint: str,
    agent_name: str = "Flow1-MCP-Agent"
) -> Dict[str, Any]:
    """
    Create a Foundry Agent with MCP tool configuration
    
    Args:
        project_endpoint: Azure AI Foundry project endpoint
        project_key: Azure AI Foundry project key
        apim_mcp_endpoint: APIM MCP endpoint URL
        agent_name: Name for the agent
        
    Returns:
        Dictionary with agent information
    """
    print(f"Creating Foundry Agent: {agent_name}")
    
    # Initialize the client
    credential = AzureKeyCredential(project_key)
    client = AIProjectClient(
        endpoint=project_endpoint,
        credential=credential
    )
    
    # Define agent instructions
    instructions = """
    You are a helpful assistant that can provide weather information.
    When users ask about weather in a city, use the get_weather tool to fetch the information.
    Always use the tool when weather information is requested.
    """
    
    # Define MCP tool configuration
    mcp_tool_config = {
        "type": "mcp",
        "mcp": {
            "server": {
                "url": apim_mcp_endpoint,
                "auth": {
                    "type": "bearer",
                    # Token will be provided at runtime from the client
                    "token": "${runtime.bearer_token}"
                }
            }
        }
    }
    
    # Create the agent
    # Note: The exact API might vary based on the Azure AI Foundry SDK version
    # This is a representative implementation
    try:
        agent = client.agents.create(
            model="gpt-4",  # or your preferred model
            name=agent_name,
            instructions=instructions,
            tools=[mcp_tool_config]
        )
        
        print(f"✓ Agent created successfully")
        print(f"  Agent ID: {agent.id}")
        print(f"  Agent Name: {agent.name}")
        
        return {
            "agent_id": agent.id,
            "agent_name": agent.name,
            "endpoint": project_endpoint,
        }
    except Exception as e:
        print(f"Error creating agent: {e}")
        raise


def main():
    parser = argparse.ArgumentParser(
        description="Create Azure AI Foundry Agent with MCP tools"
    )
    parser.add_argument(
        "--project-endpoint",
        required=True,
        help="Azure AI Foundry project endpoint"
    )
    parser.add_argument(
        "--project-key",
        required=True,
        help="Azure AI Foundry project key"
    )
    parser.add_argument(
        "--apim-endpoint",
        required=True,
        help="APIM MCP endpoint URL"
    )
    parser.add_argument(
        "--agent-name",
        default="Flow1-MCP-Agent",
        help="Name for the agent (default: Flow1-MCP-Agent)"
    )
    parser.add_argument(
        "--output",
        default="agent-config.json",
        help="Output file for agent configuration (default: agent-config.json)"
    )
    
    args = parser.parse_args()
    
    try:
        # Create the agent
        agent_info = create_foundry_agent(
            project_endpoint=args.project_endpoint,
            project_key=args.project_key,
            apim_mcp_endpoint=args.apim_endpoint,
            agent_name=args.agent_name
        )
        
        # Save configuration to file
        with open(args.output, 'w') as f:
            json.dump(agent_info, f, indent=2)
        
        print(f"\n✓ Configuration saved to: {args.output}")
        print("\nNext steps:")
        print("1. Update your Web App environment variables with the agent ID")
        print("2. Deploy the Web App to Azure")
        print("3. Test the application")
        
    except Exception as e:
        print(f"\n✗ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
