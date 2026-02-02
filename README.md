# Foundry Agent MCP Handson - Flow①

Azure AI Foundry Agent と MCP (Model Context Protocol) を使用したクラウド完結型ハンズオン実装です。

## 概要

このプロジェクトは、ユーザー識別子（Azure AD の `oid`）を使用してMCP機能をフィルタリングする Flow① を実装します。

### アーキテクチャ

```
[Web UI (Next.js)] 
    ↓ MSAL Login (Bearer Token)
    ↓
[Web Apps API (/api/chat)]
    ↓ Foundry Agent 実行 (Bearer Token 付き)
    ↓
[Azure AI Foundry Agent]
    ↓ MCP Tool 呼び出し (Bearer Token 付き)
    ↓
[APIM /mcp/filter]
    ↓ validate-jwt → oid 抽出 → X-EndUser-Id 設定
    ↓
[Azure Functions (MCP Server)]
    ↓ X-EndUser-Id に基づいて応答を変更
    ↓
[Response: 天気情報（°C or °F）]
```

### 主な機能

- **認証**: Microsoft Entra ID (Azure AD) による認証
- **JWT 検証**: APIM で JWT を検証し、ユーザー ID (`oid`) を抽出
- **ユーザー固有の応答**: ユーザー ID のハッシュ値に基づいて摂氏/華氏を切り替え
- **MCP プロトコル**: Foundry Agent と MCP Server 間の標準プロトコル実装

## 構成要素

### 1. Infrastructure (Bicep)
- Azure API Management (BasicV2)
- Azure Function App (Python 3.11)
- Azure Web App (Node.js 20)
- Application Insights
- Log Analytics Workspace

### 2. MCP Server (Azure Functions)
- Python 実装
- `get_weather` ツール
- `X-EndUser-Id` ヘッダーに基づく応答の変更

### 3. Web App (Next.js)
- MSAL 認証
- チャット UI
- `/api/chat` エンドポイント（Foundry Agent 呼び出し）

### 4. APIM Policy
- JWT 検証
- `oid` 抽出と `X-EndUser-Id` ヘッダー設定
- Function App へのプロキシ

## 前提条件

### 必須ツール
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (v2.50.0+)
- [Node.js](https://nodejs.org/) (v20+)
- [Python](https://www.python.org/) (v3.11+)
- [Azure Functions Core Tools](https://docs.microsoft.com/azure/azure-functions/functions-run-local) (v4+)
- [jq](https://stedolan.github.io/jq/) (JSON processor)

### Azure リソース
- Azure サブスクリプション
- Azure AI Foundry プロジェクト
- Azure AD アプリケーション登録

## セットアップ手順

### 1. Azure AD アプリケーション登録

1. Azure Portal で Azure AD に移動
2. 「アプリの登録」→「新規登録」
3. 以下を設定：
   - 名前: `Foundry MCP Handson`
   - サポートされているアカウントの種類: 組織のディレクトリのみ
   - リダイレクト URI: `http://localhost:3000` (開発用)
4. 登録後、以下を記録：
   - **アプリケーション (クライアント) ID**
   - **ディレクトリ (テナント) ID**
5. 「証明書とシークレット」→ API の露出 → スコープの追加
   - スコープ名: `access_as_user`
   - 同意できるのは: 管理者とユーザー
6. 「APIのアクセス許可」→「アクセス許可の追加」
   - Microsoft Graph → `User.Read`

### 2. インフラストラクチャのデプロイ

```bash
# Azure にログイン
az login

# インフラストラクチャをデプロイ
./scripts/deploy-infra.sh
```

プロンプトに従って以下を入力：
- Resource Group Name (デフォルト: `rg-foundry-mcp-handson`)
- Location (デフォルト: `japaneast`)
- Azure AD Tenant ID
- Azure AD Client ID (アプリケーション ID)
- APIM Publisher Email
- APIM Publisher Name

デプロイには約 20-30 分かかります（APIM のプロビジョニング）。

### 3. Function App (MCP Server) のデプロイ

```bash
./scripts/deploy-function.sh
```

このスクリプトは：
- Function App にコードをデプロイ
- Function キーを取得
- APIM に Function キーを設定

### 4. Azure AI Foundry Agent の作成

```bash
# 依存関係をインストール
pip install -r scripts/requirements.txt

# Agent を作成
python scripts/create_agent.py \
  --project-endpoint "https://your-foundry-endpoint.cognitiveservices.azure.com" \
  --project-key "your-foundry-key" \
  --apim-endpoint "$(jq -r '.apimMcpEndpoint' deployment-outputs.json)"
```

Agent ID は `agent-config.json` に保存されます。

### 5. Web App のデプロイ

```bash
./scripts/deploy-webapp.sh
```

プロンプトに従って以下を入力：
- Azure Foundry Endpoint
- Azure Foundry Key
- Azure Foundry Agent ID

### 6. Azure AD リダイレクト URI の更新

1. Azure Portal で Azure AD アプリに戻る
2. 「認証」→「プラットフォームの追加」→「シングルページアプリケーション」
3. リダイレクト URI を追加：
   - `deployment-outputs.json` の `webAppUrl` を使用
   - 例: `https://web-foundry-mcp-xyz.azurewebsites.net`

## ローカル開発

### MCP Server (Functions)

```bash
cd mcp-server

# 依存関係をインストール
pip install -r requirements.txt

# ローカルで実行
func start
```

エンドポイント: `http://localhost:7071/api/mcp`

### Web App

```bash
cd webapp

# 依存関係をインストール
npm install

# 環境変数を設定
cp .env.local.example .env.local
# .env.local を編集して値を設定

# 開発サーバーを起動
npm run dev
```

アプリケーション: `http://localhost:3000`

## 動作確認

### 1. APIM エンドポイントのテスト（認証なし → 401）

```bash
APIM_URL=$(jq -r '.apimMcpEndpoint' deployment-outputs.json)

curl -X POST "$APIM_URL" \
  -H "Content-Type: application/json" \
  -d '{"method":"tools/list","id":"1"}'
```

期待される結果: `401 Unauthorized`

### 2. APIM エンドポイントのテスト（認証あり）

```bash
# トークンを取得（Azure CLI 経由）
TOKEN=$(az account get-access-token --resource <CLIENT_ID> --query accessToken -o tsv)

curl -X POST "$APIM_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "method": "tools/call",
    "id": "1",
    "params": {
      "name": "get_weather",
      "arguments": {"city": "Tokyo"}
    }
  }'
```

期待される結果: 天気情報（摂氏または華氏）

### 3. Web UI でのテスト

1. Web App URL にアクセス
2. 「Sign In with Microsoft」をクリック
3. Azure AD でログイン
4. チャットで質問:
   ```
   What's the weather in Tokyo?
   ```
5. Agent が MCP ツールを使用して応答

### 4. ユーザー固有の応答の確認

異なるユーザーでログインして、温度表示が摂氏/華氏で変わることを確認：

- ユーザー A (`oid` のハッシュが偶数) → 摂氏 (°C)
- ユーザー B (`oid` のハッシュが奇数) → 華氏 (°F)

## トラブルシューティング

### APIM が 401 を返す

- JWT の issuer と audience が正しく設定されているか確認
- トークンの有効期限が切れていないか確認

### Function が応答しない

- Function App が起動しているか確認
- APIM に正しい Function キーが設定されているか確認
- Application Insights でログを確認

### Web App がエラーを返す

- 環境変数が正しく設定されているか確認
- Foundry Agent ID が正しいか確認
- APIM エンドポイントが正しいか確認

### ログの確認

```bash
# Function App のログ
az webapp log tail -n func-foundry-mcp-xyz -g rg-foundry-mcp-handson

# Web App のログ
az webapp log tail -n web-foundry-mcp-xyz -g rg-foundry-mcp-handson
```

## クリーンアップ

```bash
# リソースグループごと削除
az group delete --name rg-foundry-mcp-handson --yes --no-wait
```

## アーキテクチャの詳細

### JWT 検証フロー

1. クライアントが Azure AD からトークンを取得
2. クライアントが APIM にリクエスト（Bearer トークン付き）
3. APIM が `validate-jwt` ポリシーで検証：
   - issuer: `https://login.microsoftonline.com/{tenantId}/v2.0`
   - audience: `{clientId}`
4. 検証成功後、`oid` クレームを抽出
5. `X-EndUser-Id` ヘッダーを設定して Function に転送

### MCP プロトコル

このプロジェクトは MCP (Model Context Protocol) を実装しています：

- **tools/list**: 利用可能なツールのリスト
- **tools/call**: ツールの実行

詳細: [MCP Specification](https://modelcontextprotocol.io/)

## 参考資料

- [Azure AI Foundry](https://learn.microsoft.com/azure/ai-studio/)
- [Azure API Management](https://learn.microsoft.com/azure/api-management/)
- [Azure Functions](https://learn.microsoft.com/azure/azure-functions/)
- [MSAL.js](https://github.com/AzureAD/microsoft-authentication-library-for-js)
- [Model Context Protocol](https://modelcontextprotocol.io/)

## ライセンス

MIT License

## 貢献

プルリクエストを歓迎します！

## サポート

問題がある場合は、GitHub Issues を開いてください。