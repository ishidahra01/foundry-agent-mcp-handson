# Testing Guide - Flow①

このガイドでは、Flow① の各コンポーネントをテストする方法を説明します。

## テストシナリオ

### シナリオ 1: MCP Server の直接テスト

#### 1.1 ツール一覧の取得

```bash
# ローカル
curl http://localhost:7071/api/mcp

# Azure (Function キー必要)
FUNCTION_NAME=$(jq -r '.functionName' deployment-outputs.json)
FUNCTION_KEY=$(az functionapp keys list -g rg-foundry-mcp-handson -n $FUNCTION_NAME --query "functionKeys.default" -o tsv)

curl "https://${FUNCTION_NAME}.azurewebsites.net/api/mcp?code=${FUNCTION_KEY}"
```

期待される応答:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "tools": [
      {
        "name": "get_weather",
        "description": "Get weather information...",
        "inputSchema": {...}
      }
    ]
  }
}
```

#### 1.2 ツールの実行（偶数ユーザー → 摂氏）

```bash
curl -X POST http://localhost:7071/api/mcp \
  -H "Content-Type: application/json" \
  -H "X-EndUser-Id: 00000000-0000-0000-0000-000000000000" \
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
  }'
```

期待される応答:
```json
{
  "jsonrpc": "2.0",
  "id": "1",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"city\":\"Tokyo\",\"temperature\":\"15°C\",\"condition\":\"Partly cloudy\",\"unit\":\"Celsius\"}"
      }
    ]
  }
}
```

#### 1.3 ツールの実行（奇数ユーザー → 華氏）

```bash
curl -X POST http://localhost:7071/api/mcp \
  -H "Content-Type: application/json" \
  -H "X-EndUser-Id: 00000000-0000-0000-0000-000000000001" \
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
  }'
```

期待される応答: 華氏 (°F) の温度

### シナリオ 2: APIM 経由のテスト

#### 2.1 認証なし → 401

```bash
APIM_URL=$(jq -r '.apimMcpEndpoint' deployment-outputs.json)

curl -X POST "$APIM_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "id": "1"
  }' \
  -w "\nHTTP Status: %{http_code}\n"
```

期待される結果: HTTP 401

#### 2.2 認証あり → 成功

```bash
# Azure AD トークンを取得
CLIENT_ID=$(jq -r '.clientId' deployment-outputs.json)
TOKEN=$(az account get-access-token \
  --resource "api://${CLIENT_ID}" \
  --query accessToken -o tsv)

# リクエスト
curl -X POST "$APIM_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "id": "1",
    "params": {
      "name": "get_weather",
      "arguments": {"city": "Tokyo"}
    }
  }' | jq .
```

### シナリオ 3: Web App の統合テスト

#### 3.1 Web App にアクセス

```bash
WEBAPP_URL=$(jq -r '.webAppUrl' deployment-outputs.json)
echo "Web App URL: $WEBAPP_URL"
```

ブラウザで開いて：
1. 「Sign In with Microsoft」をクリック
2. Azure AD でログイン
3. メッセージを送信: "What's the weather in Tokyo?"

#### 3.2 レスポンスの確認

Agent が MCP ツールを使用して応答を生成することを確認。

### シナリオ 4: 複数ユーザーでの動作確認

2つの異なる Azure AD ユーザーでログインして、温度単位が異なることを確認：

**テストケース:**

| ユーザー | `oid` の例 | ハッシュ | 温度単位 |
|---------|-----------|---------|---------|
| User A  | `...000`  | 偶数    | °C      |
| User B  | `...001`  | 奇数    | °F      |

## デバッグツール

### JWT トークンのデコード

```bash
# トークンをデコードして内容を確認
decode_jwt() {
  local token=$1
  echo $token | cut -d'.' -f2 | base64 -d 2>/dev/null | jq .
}

TOKEN=$(az account get-access-token --query accessToken -o tsv)
decode_jwt $TOKEN
```

期待される出力に `oid` クレームが含まれていることを確認。

### Application Insights クエリ

```bash
# 直近1時間のログを取得
az monitor app-insights query \
  --app $(jq -r '.appInsightsName' deployment-outputs.json) \
  --analytics-query "traces | where timestamp > ago(1h) | project timestamp, message | order by timestamp desc | take 50"
```

### APIM トレース

APIM ポータルで「Test」タブからトレースを有効化してリクエストを送信。

## 自動テストスクリプト

### 統合テストスクリプト

```bash
#!/bin/bash
# test-flow1.sh

set -e

echo "=== Flow① Integration Test ==="

# 1. MCP Server テスト
echo "Testing MCP Server..."
curl -s http://localhost:7071/api/mcp > /dev/null && echo "✓ MCP Server is running" || echo "✗ MCP Server is not running"

# 2. ツール実行テスト（偶数ユーザー）
echo "Testing even user (Celsius)..."
RESPONSE=$(curl -s -X POST http://localhost:7071/api/mcp \
  -H "Content-Type: application/json" \
  -H "X-EndUser-Id: user-even" \
  -d '{"jsonrpc":"2.0","method":"tools/call","id":"1","params":{"name":"get_weather","arguments":{"city":"Tokyo"}}}')

if echo $RESPONSE | jq -r '.result.content[0].text' | grep -q "°C"; then
  echo "✓ Celsius response for even user"
else
  echo "✗ Expected Celsius but got: $RESPONSE"
fi

# 3. ツール実行テスト（奇数ユーザー）
echo "Testing odd user (Fahrenheit)..."
RESPONSE=$(curl -s -X POST http://localhost:7071/api/mcp \
  -H "Content-Type: application/json" \
  -H "X-EndUser-Id: user-odd" \
  -d '{"jsonrpc":"2.0","method":"tools/call","id":"1","params":{"name":"get_weather","arguments":{"city":"Tokyo"}}}')

if echo $RESPONSE | jq -r '.result.content[0].text' | grep -q "°F"; then
  echo "✓ Fahrenheit response for odd user"
else
  echo "✗ Expected Fahrenheit but got: $RESPONSE"
fi

echo "=== Tests Complete ==="
```

実行:
```bash
chmod +x test-flow1.sh
./test-flow1.sh
```

## パフォーマンステスト

### 負荷テスト (Apache Bench)

```bash
# 100リクエスト、同時10接続
ab -n 100 -c 10 \
  -H "Content-Type: application/json" \
  -H "X-EndUser-Id: test-user" \
  -p post-data.json \
  http://localhost:7071/api/mcp
```

`post-data.json`:
```json
{"jsonrpc":"2.0","method":"tools/call","id":"1","params":{"name":"get_weather","arguments":{"city":"Tokyo"}}}
```

## トラブルシューティングチェックリスト

- [ ] Function App が起動している
- [ ] APIM が稼働している  
- [ ] JWT の issuer/audience が正しい
- [ ] Function キーが APIM に設定されている
- [ ] CORS 設定が正しい
- [ ] 環境変数が設定されている
- [ ] トークンの有効期限が切れていない
- [ ] ネットワーク接続が正常

## まとめ

各シナリオを実行して、すべてのコンポーネントが正しく動作していることを確認してください。問題がある場合は、Application Insights のログを確認してください。
