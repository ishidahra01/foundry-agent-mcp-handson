# Architecture Diagram - Flow①

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Flow① Architecture                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────┐
│   Browser    │
│              │
│  Web UI      │
│  (Next.js)   │
└──────┬───────┘
       │ 1. User clicks "Sign In"
       │
       ▼
┌──────────────────┐
│  Microsoft       │
│  Entra ID        │◄─────────── 2. Redirect to Azure AD
│  (Azure AD)      │──────────┐
└──────────────────┘          │
                              │ 3. Return access token (JWT)
                              │
┌──────────────┐              │
│   Browser    │◄─────────────┘
│              │
│  Web UI      │
│  + Token     │
└──────┬───────┘
       │ 4. POST /api/chat
       │    Header: Authorization: Bearer <token>
       │    Body: { message: "What's the weather?" }
       │
       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Web App (Azure Web Apps)                             │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  /api/chat Handler                                                     │ │
│  │                                                                        │ │
│  │  1. Receive request with Bearer token                                 │ │
│  │  2. Call Azure AI Foundry Agent                                       │ │
│  │  3. Pass Bearer token for MCP tool calls                              │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │ 5. Create thread & execute agent
                                   │    with MCP tool configuration
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Azure AI Foundry Agent                                  │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  Agent: Flow1-MCP-Agent                                                │ │
│  │  Model: GPT-4                                                          │ │
│  │  Instructions: "Use get_weather tool when needed"                     │ │
│  │                                                                        │ │
│  │  Tools:                                                                │ │
│  │    - MCP Tool (APIM endpoint)                                          │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │ 6. Decide to call get_weather tool
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Azure API Management (APIM)                             │
│                                                                              │
│  Endpoint: /mcp/filter                                                       │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  Inbound Policy:                                                       │ │
│  │                                                                        │ │
│  │  1. validate-jwt                                                       │ │
│  │     - Check issuer: login.microsoftonline.com/{tenantId}               │ │
│  │     - Check audience: {clientId}                                       │ │
│  │     - Verify signature using OpenID config                             │ │
│  │                                                                        │ │
│  │  2. Extract claims from JWT                                            │ │
│  │     jwt = context.Request.Headers["Authorization"].AsJwt()             │ │
│  │     oid = jwt.Claims["oid"]                                            │ │
│  │                                                                        │ │
│  │  3. set-header (OVERRIDE)                                              │ │
│  │     X-EndUser-Id: {oid}                                                │ │
│  │                                                                        │ │
│  │  4. rewrite-uri                                                        │ │
│  │     /mcp/filter/* -> /api/mcp                                          │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │ 7. Forward to Function App
                                   │    Header: X-EndUser-Id: {oid}
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                   Azure Function App (MCP Server)                            │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  MCP Server (Python)                                                   │ │
│  │                                                                        │ │
│  │  1. Read X-EndUser-Id header                                           │ │
│  │     user_id = req.headers.get('X-EndUser-Id')                          │ │
│  │                                                                        │ │
│  │  2. Calculate hash                                                     │ │
│  │     user_hash = sum(ord(c) for c in user_id)                           │ │
│  │                                                                        │ │
│  │  3. Determine unit based on hash                                       │ │
│  │     if user_hash % 2 == 0:                                             │ │
│  │         return "15°C"   # Celsius for even hash                        │ │
│  │     else:                                                              │ │
│  │         return "59°F"   # Fahrenheit for odd hash                      │ │
│  │                                                                        │ │
│  │  4. Return result                                                      │ │
│  │     {                                                                  │ │
│  │       "city": "Tokyo",                                                 │ │
│  │       "temperature": "15°C",                                           │ │
│  │       "condition": "Partly cloudy",                                    │ │
│  │       "unit": "Celsius"                                                │ │
│  │     }                                                                  │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   │ 8. Response flows back
                                   │
                                   ▼
                        Function → APIM → Agent → Web App → Browser


┌─────────────────────────────────────────────────────────────────────────────┐
│                          Key Security Features                               │
└─────────────────────────────────────────────────────────────────────────────┘

✓ JWT Validation at APIM
  - Prevents unauthorized access
  - Validates token signature, issuer, and audience
  
✓ User Identity Extraction
  - APIM extracts 'oid' (Object ID) from JWT
  - Overrides X-EndUser-Id header (untrusted client headers ignored)
  
✓ HTTPS Everywhere
  - All connections use HTTPS
  - TLS 1.2+ enforced
  
✓ No Direct Function Access
  - Function App only accessible through APIM
  - Function key protected in APIM named values


┌─────────────────────────────────────────────────────────────────────────────┐
│                          Data Flow Summary                                   │
└─────────────────────────────────────────────────────────────────────────────┘

User → Azure AD → Token (with 'oid' claim)
                    ↓
                 Web App → Foundry Agent (with token)
                              ↓
                           APIM → Validate JWT
                              ↓   Extract 'oid'
                              ↓   Set X-EndUser-Id
                              ↓
                        Function App → Generate response based on user ID
                              ↓
                          Response → Agent → Web App → User


┌─────────────────────────────────────────────────────────────────────────────┐
│                     User-Specific Response Logic                             │
└─────────────────────────────────────────────────────────────────────────────┘

User A                              User B
  oid: abc-123 (hash: 894)            oid: xyz-789 (hash: 1337)
       ↓                                   ↓
  Even hash (894 % 2 = 0)            Odd hash (1337 % 2 = 1)
       ↓                                   ↓
  Celsius (°C)                       Fahrenheit (°F)
       ↓                                   ↓
  "Tokyo: 15°C"                      "Tokyo: 59°F"

