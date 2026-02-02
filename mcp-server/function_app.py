import json
import logging
import azure.functions as func
from typing import Any, Dict, List

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

# MCP Tools definition
TOOLS = [
    {
        "name": "get_weather",
        "description": "Get weather information for a city. Returns temperature in Celsius or Fahrenheit based on user preference.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "city": {
                    "type": "string",
                    "description": "The city name to get weather for"
                }
            },
            "required": ["city"]
        }
    }
]

def get_weather_result(city: str, user_id: str) -> Dict[str, Any]:
    """
    Get weather information for a city.
    User ID determines the temperature unit:
    - Even hash: Celsius
    - Odd hash: Fahrenheit
    """
    # Simple hash to determine preference
    user_hash = sum(ord(c) for c in user_id)
    use_celsius = (user_hash % 2 == 0)
    
    # Mock weather data
    weather_data = {
        "tokyo": {"temp_c": 15, "condition": "Partly cloudy"},
        "osaka": {"temp_c": 18, "condition": "Sunny"},
        "new york": {"temp_c": 10, "condition": "Rainy"},
        "london": {"temp_c": 8, "condition": "Cloudy"},
        "paris": {"temp_c": 12, "condition": "Clear"}
    }
    
    city_lower = city.lower()
    if city_lower not in weather_data:
        return {
            "error": f"Weather data not available for {city}",
            "available_cities": list(weather_data.keys())
        }
    
    data = weather_data[city_lower]
    
    if use_celsius:
        return {
            "city": city,
            "temperature": f"{data['temp_c']}°C",
            "condition": data['condition'],
            "unit": "Celsius",
            "user_preference": "Even user ID hash - Celsius"
        }
    else:
        temp_f = int(data['temp_c'] * 9/5 + 32)
        return {
            "city": city,
            "temperature": f"{temp_f}°F",
            "condition": data['condition'],
            "unit": "Fahrenheit",
            "user_preference": "Odd user ID hash - Fahrenheit"
        }

@app.route(route="mcp", methods=["POST", "GET"], auth_level=func.AuthLevel.FUNCTION)
def mcp_endpoint(req: func.HttpRequest) -> func.HttpResponse:
    """
    MCP Server endpoint following the MCP protocol
    Supports tool listing and execution
    """
    logging.info('MCP endpoint called')
    
    # Get user ID from header (set by APIM)
    user_id = req.headers.get('X-EndUser-Id', 'unknown')
    logging.info(f'User ID: {user_id}')
    
    try:
        # Handle GET requests (list tools)
        if req.method == "GET":
            return func.HttpResponse(
                json.dumps({
                    "jsonrpc": "2.0",
                    "result": {
                        "tools": TOOLS
                    }
                }),
                mimetype="application/json",
                status_code=200
            )
        
        # Handle POST requests (execute tool)
        body = req.get_json()
        
        # Check if this is a tools/list request
        if body.get("method") == "tools/list":
            return func.HttpResponse(
                json.dumps({
                    "jsonrpc": "2.0",
                    "id": body.get("id"),
                    "result": {
                        "tools": TOOLS
                    }
                }),
                mimetype="application/json",
                status_code=200
            )
        
        # Check if this is a tools/call request
        if body.get("method") == "tools/call":
            params = body.get("params", {})
            tool_name = params.get("name")
            tool_arguments = params.get("arguments", {})
            
            if tool_name == "get_weather":
                city = tool_arguments.get("city", "Tokyo")
                result = get_weather_result(city, user_id)
                
                return func.HttpResponse(
                    json.dumps({
                        "jsonrpc": "2.0",
                        "id": body.get("id"),
                        "result": {
                            "content": [
                                {
                                    "type": "text",
                                    "text": json.dumps(result, indent=2)
                                }
                            ]
                        }
                    }),
                    mimetype="application/json",
                    status_code=200
                )
            else:
                return func.HttpResponse(
                    json.dumps({
                        "jsonrpc": "2.0",
                        "id": body.get("id"),
                        "error": {
                            "code": -32601,
                            "message": f"Tool not found: {tool_name}"
                        }
                    }),
                    mimetype="application/json",
                    status_code=404
                )
        
        # Unknown method
        return func.HttpResponse(
            json.dumps({
                "jsonrpc": "2.0",
                "id": body.get("id"),
                "error": {
                    "code": -32601,
                    "message": f"Method not found: {body.get('method')}"
                }
            }),
            mimetype="application/json",
            status_code=400
        )
        
    except Exception as e:
        logging.error(f'Error processing request: {str(e)}')
        return func.HttpResponse(
            json.dumps({
                "jsonrpc": "2.0",
                "error": {
                    "code": -32603,
                    "message": f"Internal error: {str(e)}"
                }
            }),
            mimetype="application/json",
            status_code=500
        )
