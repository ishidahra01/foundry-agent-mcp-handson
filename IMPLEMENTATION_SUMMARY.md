# Flow① Implementation Summary

このドキュメントは、Flow①（ユーザ識別子でMCP機能フィルタ）クラウド完結ハンズオンの実装の完全な概要を提供します。

## 📋 実装完了項目

### ✅ すべての必須コンポーネント

1. **Infrastructure as Code (Bicep)**
   - `infra/main.bicep`: メインデプロイテンプレート
   - `infra/resources.bicep`: リソース定義
   - `infra/parameters.json`: パラメータ設定

2. **MCP Server (Azure Functions - Python)**
   - `mcp-server/function_app.py`: メインロジック
   - `mcp-server/requirements.txt`: Python依存関係
   - `mcp-server/host.json`: Functions設定

3. **Web App (Next.js - TypeScript)**
   - `webapp/app/page.tsx`: チャット UI
   - `webapp/app/api/chat/route.ts`: Foundry Agent API
   - `webapp/lib/authConfig.ts`: MSAL認証設定

4. **デプロイスクリプト**
   - `scripts/deploy-infra.sh`: インフラデプロイ
   - `scripts/deploy-function.sh`: Function デプロイ
   - `scripts/deploy-webapp.sh`: Web App デプロイ
   - `scripts/create_agent.py`: Foundry Agent 作成

5. **テストスクリプト**
   - `scripts/test-local.sh`: ローカル統合テスト

6. **ドキュメント**
   - `README.md`: メイン README
   - `docs/QUICKSTART.md`: クイックスタート
   - `docs/ARCHITECTURE.md`: アーキテクチャ図
   - `docs/IMPLEMENTATION_GUIDE.md`: 実装詳細
   - `docs/TESTING.md`: テストガイド
   - `docs/ACCEPTANCE_CHECKLIST.md`: 受け入れ基準
   - `CONTRIBUTING.md`: 貢献ガイド

## 🎯 主要機能

### 1. 認証とセキュリティ

- **Microsoft Entra ID (Azure AD) 認証**
  - MSAL.js によるシングルサインオン
  - Bearer トークン による API 保護

- **APIM での JWT 検証**
  - OpenID Connect メタデータ使用
  - issuer/audience 検証
  - 署名検証

- **ユーザー識別子の抽出**
  - JWT から `oid` クレームを抽出
  - `X-EndUser-Id` ヘッダーに設定
  - クライアントからの偽装を防止

### 2. ユーザー固有の応答

```python
# MCP Server のロジック
user_hash = sum(ord(c) for c in user_id)
use_celsius = (user_hash % 2 == 0)

if use_celsius:
    return "15°C"  # 偶数ハッシュ → 摂氏
else:
    return "59°F"  # 奇数ハッシュ → 華氏
```

### 3. MCP プロトコル実装

- **tools/list**: 利用可能なツールのリスト
- **tools/call**: ツールの実行
- JSON-RPC 2.0 準拠

## 🏗️ アーキテクチャ

```
Browser (MSAL Auth) 
  ↓ Bearer Token
Web App (Next.js)
  ↓ Call Agent with Token
Azure AI Foundry Agent
  ↓ MCP Tool Call with Token
APIM
  ↓ Validate JWT → Extract oid → Set X-EndUser-Id
Azure Function (MCP Server)
  ↓ Read X-EndUser-Id → Generate Response
Response (Celsius or Fahrenheit)
```

## 📦 デプロイされるリソース

| リソース | SKU/プラン | 用途 |
|---------|----------|------|
| APIM | BasicV2 | JWT検証とルーティング |
| Function App | Consumption (Linux) | MCP Server |
| Web App | B1 (Linux) | Next.js UI |
| App Insights | - | 監視とログ |
| Log Analytics | PerGB2018 | ログストレージ |
| Storage Account | Standard_LRS | Function データ |

## 🚀 デプロイ手順（要約）

### 1. 前提条件

```bash
# 必要なツール
- Azure CLI
- Node.js 20+
- Python 3.11+
- Azure Functions Core Tools
- jq
```

### 2. Azure AD アプリ登録

- Client ID と Tenant ID を取得

### 3. デプロイ実行

```bash
# 1. インフラ（20-30分）
./scripts/deploy-infra.sh

# 2. Function（2-3分）
./scripts/deploy-function.sh

# 3. Agent 作成（1-2分）
python scripts/create_agent.py \
  --project-endpoint <endpoint> \
  --project-key <key> \
  --apim-endpoint $(jq -r '.apimMcpEndpoint' deployment-outputs.json)

# 4. Web App（5-10分）
./scripts/deploy-webapp.sh
```

## 🧪 テスト方法

### ローカルテスト

```bash
# MCP Server を起動
cd mcp-server && func start

# 別のターミナルで
./scripts/test-local.sh
```

### Azure テスト

```bash
# 1. 認証なし → 401
curl -X POST $(jq -r '.apimMcpEndpoint' deployment-outputs.json)

# 2. 認証あり → 成功
TOKEN=$(az account get-access-token --resource "api://$(jq -r '.clientId' deployment-outputs.json)" --query accessToken -o tsv)
curl -X POST $(jq -r '.apimMcpEndpoint' deployment-outputs.json) \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"method":"tools/list","id":"1"}'

# 3. Web UI
# ブラウザで $(jq -r '.webAppUrl' deployment-outputs.json) を開く
```

## ✅ 受け入れ基準

- [x] トークン無しで APIM は 401 を返す
- [x] トークンありで MCP tool が動作する
- [x] 異なるユーザーで結果が変わる（摂氏/華氏）
- [x] README に完全なデプロイ手順がある

## 📚 ドキュメント構成

```
foundry-agent-mcp-handson/
├── README.md                      # メイン README（日本語）
├── CONTRIBUTING.md                # 貢献ガイド
├── docs/
│   ├── QUICKSTART.md              # 5分で試すガイド
│   ├── ARCHITECTURE.md            # アーキテクチャ図（詳細）
│   ├── IMPLEMENTATION_GUIDE.md    # 実装の詳細解説
│   ├── TESTING.md                 # テスト方法（curl例）
│   └── ACCEPTANCE_CHECKLIST.md    # 受け入れ基準チェックリスト
```

## 🔍 主要なファイル

### インフラ

- `infra/main.bicep`: サブスクリプションレベルのデプロイ
- `infra/resources.bicep`: すべてのリソース定義（APIM, Functions, Web App, etc）
- `infra/parameters.json`: デプロイパラメータ

### MCP Server

- `mcp-server/function_app.py`: 
  - MCP プロトコル実装
  - `get_weather` ツール
  - ユーザー固有ロジック

### Web App

- `webapp/app/page.tsx`: チャット UI（MSAL統合）
- `webapp/app/api/chat/route.ts`: Foundry Agent 呼び出し
- `webapp/lib/authConfig.ts`: MSAL設定

### スクリプト

- `scripts/deploy-infra.sh`: Bicepデプロイの自動化
- `scripts/deploy-function.sh`: Function デプロイ + APIM設定
- `scripts/deploy-webapp.sh`: Web App ビルド & デプロイ
- `scripts/create_agent.py`: Foundry Agent セットアップ
- `scripts/test-local.sh`: ローカル統合テスト

## 🔒 セキュリティ機能

1. **JWT 検証**: APIM で完全な JWT 検証
2. **ヘッダー上書き**: クライアントからの `X-EndUser-Id` は無視
3. **HTTPS 強制**: すべてのエンドポイントで HTTPS
4. **Function キー保護**: APIM の Named Values で保護
5. **CORS 設定**: 適切な Origin 制限

## 🎓 学習ポイント

このハンズオンで学べること：

1. **Azure AI Foundry Agent** の使い方
2. **MCP (Model Context Protocol)** の実装
3. **APIM** での JWT 検証とヘッダー操作
4. **Azure Functions** での HTTP トリガー
5. **Next.js** + **MSAL** での認証
6. **Infrastructure as Code** (Bicep)
7. **エンドツーエンドのデプロイ自動化**

## 🚧 今後の拡張案

- [ ] 追加の MCP ツール（ニュース、為替レート等）
- [ ] ユーザープリファレンスのデータベース保存
- [ ] 会話履歴の永続化
- [ ] より詳細なログとメトリクス
- [ ] CI/CD パイプライン（GitHub Actions）
- [ ] 複数環境（dev/staging/prod）のサポート

## 💡 トラブルシューティング

よくある問題と解決方法は `docs/TESTING.md` と `README.md` のトラブルシューティングセクションを参照してください。

## 📞 サポート

- **Issues**: GitHub Issues で質問
- **Docs**: `docs/` ディレクトリの詳細ドキュメント
- **Testing**: `scripts/test-local.sh` でローカルテスト

## 🎉 完了状態

このプロジェクトは、Issue で要求されたすべての機能を実装しています：

✅ Bicep による完全なインフラ定義  
✅ APIM での JWT 検証と `oid` 抽出  
✅ Function での `X-EndUser-Id` ベースの応答  
✅ Next.js での MSAL 認証  
✅ Foundry Agent 作成スクリプト  
✅ 完全なデプロイ自動化  
✅ 包括的なドキュメント  
✅ ローカル＆Azure テスト手順  

---

**Ready for deployment and use!** 🚀
