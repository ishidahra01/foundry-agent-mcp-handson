import { NextRequest, NextResponse } from 'next/server';

/**
 * Chat API endpoint that calls Azure AI Foundry Agent
 * The agent will use MCP tools via APIM
 */
export async function POST(request: NextRequest) {
  try {
    // Get authorization header
    const authorization = request.headers.get('authorization');
    if (!authorization) {
      return NextResponse.json(
        { error: 'Authorization header required' },
        { status: 401 }
      );
    }

    // Parse request body
    const { message } = await request.json();
    if (!message) {
      return NextResponse.json(
        { error: 'Message is required' },
        { status: 400 }
      );
    }

    // Get Foundry configuration from environment
    const foundryEndpoint = process.env.AZURE_FOUNDRY_ENDPOINT;
    const foundryKey = process.env.AZURE_FOUNDRY_KEY;
    const agentId = process.env.AZURE_FOUNDRY_AGENT_ID;

    if (!foundryEndpoint || !foundryKey || !agentId) {
      return NextResponse.json(
        { error: 'Foundry configuration not found. Please set environment variables.' },
        { status: 500 }
      );
    }

    // Call Azure AI Foundry Agent
    // Note: This is a simplified implementation
    // In production, use the Azure AI Foundry SDK
    const foundryResponse = await fetch(`${foundryEndpoint}/agents/${agentId}/threads/runs`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'api-key': foundryKey,
        // Pass the user's bearer token for MCP tool calls
        'Authorization': authorization,
      },
      body: JSON.stringify({
        messages: [
          {
            role: 'user',
            content: message,
          },
        ],
        // Configuration for MCP tools
        tools: [
          {
            type: 'mcp',
            mcp: {
              server: {
                url: process.env.APIM_MCP_ENDPOINT || '',
                // The bearer token will be passed through to APIM
                auth: {
                  type: 'bearer',
                  token: authorization.replace('Bearer ', ''),
                },
              },
            },
          },
        ],
      }),
    });

    if (!foundryResponse.ok) {
      const errorText = await foundryResponse.text();
      console.error('Foundry API error:', errorText);
      return NextResponse.json(
        { error: 'Failed to call Foundry Agent', details: errorText },
        { status: foundryResponse.status }
      );
    }

    const foundryData = await foundryResponse.json();

    // Extract the assistant's response
    const assistantMessage = foundryData.messages?.find(
      (m: any) => m.role === 'assistant'
    );

    return NextResponse.json({
      response: assistantMessage?.content || 'No response from agent',
      raw: foundryData,
    });
  } catch (error) {
    console.error('Chat API error:', error);
    return NextResponse.json(
      { 
        error: 'Internal server error',
        details: error instanceof Error ? error.message : 'Unknown error'
      },
      { status: 500 }
    );
  }
}
