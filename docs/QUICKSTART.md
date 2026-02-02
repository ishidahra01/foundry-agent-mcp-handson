# Quick Start Guide - Flow①

最速で Flow① を試すためのガイドです。

## 5分でローカル環境を試す

### 前提条件
- Node.js 20+
- Python 3.11+
- Azure Functions Core Tools

### 1. MCP Server をローカルで起動

```bash
cd mcp-server
pip install -r requirements.txt
func start
```

→ `http://localhost:7071/api/mcp` で起動

### 2. テストリクエスト

```bash
# ツール一覧
curl http://localhost:7071/api/mcp

# ツール実行（ユーザー ID を指定）
curl -X POST http://localhost:7071/api/mcp \
  -H "Content-Type: application/json" \
  -H "X-EndUser-Id: user123" \
  -d '{
    "method": "tools/call",
    "id": "1",
    "params": {
      "name": "get_weather",
      "arguments": {"city": "Tokyo"}
    }
  }'
```

### 3. 異なるユーザー ID で試す

```bash
# 偶数ハッシュ → 摂氏
curl -X POST http://localhost:7071/api/mcp \
  -H "X-EndUser-Id: user-even-123" \
  -d '{"method":"tools/call","id":"1","params":{"name":"get_weather","arguments":{"city":"Tokyo"}}}'

# 奇数ハッシュ → 華氏
curl -X POST http://localhost:7071/api/mcp \
  -H "X-EndUser-Id: user-odd-456" \
  -d '{"method":"tools/call","id":"1","params":{"name":"get_weather","arguments":{"city":"Tokyo"}}}'
```

## Azure デプロイ（30分）

### 1. 準備

```bash
# Azure にログイン
az login

# 必要なツールのインストール確認
which az node python func jq
```

### 2. Azure AD アプリ登録

1. [Azure Portal](https://portal.azure.com) にアクセス
2. Azure Active Directory → アプリの登録 → 新規登録
3. Client ID と Tenant ID を記録

### 3. デプロイ実行

```bash
# インフラストラクチャ（20-30分）
./scripts/deploy-infra.sh

# Function App（2-3分）
./scripts/deploy-function.sh

# Foundry Agent 作成
pip install -r scripts/requirements.txt
python scripts/create_agent.py \
  --project-endpoint "YOUR_ENDPOINT" \
  --project-key "YOUR_KEY" \
  --apim-endpoint "$(jq -r '.apimMcpEndpoint' deployment-outputs.json)"

# Web App（5-10分）
./scripts/deploy-webapp.sh
```

### 4. 動作確認

```bash
# APIM エンドポイントをテスト
APIM_URL=$(jq -r '.apimMcpEndpoint' deployment-outputs.json)

# 認証なし → 401
curl -X POST "$APIM_URL" -d '{}'

# 認証あり → 成功（トークンが必要）
```

## トラブルシューティング

### Function が起動しない
```bash
# ログを確認
az webapp log tail -n $(jq -r '.functionName' deployment-outputs.json) \
  -g $(jq -r '.resourceGroup' deployment-outputs.json)
```

### APIM のデプロイが遅い
APIM BasicV2 のプロビジョニングには 20-30 分かかります。気長に待ちましょう。

### Web App が起動しない
```bash
# 設定を確認
az webapp config appsettings list \
  -n $(jq -r '.webAppName' deployment-outputs.json) \
  -g $(jq -r '.resourceGroup' deployment-outputs.json)
```

## 次のステップ

1. 本番環境用の設定をカスタマイズ
2. 追加の MCP ツールを実装
3. より複雑なユーザー固有ロジックを実装
4. モニタリングとアラートを設定

詳細は [README.md](../README.md) を参照してください。
