# Flow① Acceptance Criteria Checklist

このドキュメントは、Flow① の受け入れ条件をチェックするためのリストです。

## 機能要件

### ✅ 必須機能

- [ ] **JWT 認証**: トークンなしで APIM の MCP endpoint は 401 を返す
  - テスト方法: `curl -X POST <APIM_URL>/mcp/filter` (トークンなし)
  - 期待される結果: HTTP 401 Unauthorized

- [ ] **MCP Tool の動作**: トークンありで MCP tool が動く
  - テスト方法: Bearer トークン付きで APIM 経由でツールを呼び出す
  - 期待される結果: 天気情報が返される

- [ ] **ユーザー固有の応答**: 別ユーザーで結果が変わる（`X-EndUser-Id` 起点）
  - テスト方法: 異なる `oid` を持つユーザーでログイン
  - 期待される結果:
    - 偶数ハッシュのユーザー → 摂氏 (°C)
    - 奇数ハッシュのユーザー → 華氏 (°F)

- [ ] **ドキュメント**: `README.md` に「デプロイ→動作確認」が1本の手順で書かれている
  - 確認: README.md のセットアップ手順が明確で完結している

## 実装タスク

### ✅ インフラストラクチャ

- [x] **Bicep テンプレート**
  - [x] `infra/main.bicep`: サブスクリプションレベルのデプロイ
  - [x] `infra/resources.bicep`: リソース定義
  - [x] `infra/parameters.json`: パラメータファイル
  - [x] APIM の定義
  - [x] Function App の定義
  - [x] Web App の定義
  - [x] Application Insights の定義

- [x] **APIM Policy**
  - [x] `validate-jwt` による JWT 検証
  - [x] `oid` クレームの抽出
  - [x] `X-EndUser-Id` ヘッダーの設定（override）
  - [x] Function App へのプロキシ設定

### ✅ MCP Server (Azure Functions)

- [x] **Function 実装** (`mcp-server/function_app.py`)
  - [x] GET エンドポイント: ツール一覧
  - [x] POST エンドポイント: ツール実行
  - [x] `get_weather` ツールの実装
  - [x] `X-EndUser-Id` ヘッダーの読み取り
  - [x] ユーザー ID ハッシュに基づく応答の変更

- [x] **設定ファイル**
  - [x] `requirements.txt`: 依存関係
  - [x] `host.json`: Functions 設定

### ✅ Web App (Next.js)

- [x] **UI 実装**
  - [x] トップページ (`app/page.tsx`)
  - [x] チャット UI
  - [x] MSAL 認証統合
  - [x] ログイン/ログアウト機能

- [x] **API エンドポイント** (`app/api/chat/route.ts`)
  - [x] POST `/api/chat`
  - [x] Bearer トークンの検証
  - [x] Foundry Agent の呼び出し
  - [x] エラーハンドリング

- [x] **設定**
  - [x] `lib/authConfig.ts`: MSAL 設定
  - [x] `.env.local.example`: 環境変数テンプレート
  - [x] `package.json`: 依存関係

### ✅ Foundry Agent

- [x] **セットアップスクリプト** (`scripts/create_agent.py`)
  - [x] Foundry Project への接続
  - [x] Agent の作成
  - [x] MCP ツールの登録
  - [x] 設定の保存

### ✅ デプロイスクリプト

- [x] **インフラストラクチャ** (`scripts/deploy-infra.sh`)
  - [x] Bicep デプロイ
  - [x] パラメータの入力
  - [x] 出力の保存

- [x] **Function App** (`scripts/deploy-function.sh`)
  - [x] Function コードのデプロイ
  - [x] Function キーの取得
  - [x] APIM への Function キー設定

- [x] **Web App** (`scripts/deploy-webapp.sh`)
  - [x] Web App のビルド
  - [x] 環境変数の設定
  - [x] デプロイ

### ✅ ドキュメント

- [x] **README.md**
  - [x] 概要
  - [x] アーキテクチャ説明
  - [x] 前提条件
  - [x] セットアップ手順（1本の流れ）
  - [x] 動作確認手順（curl と UI）
  - [x] トラブルシューティング

- [x] **追加ドキュメント**
  - [x] `docs/QUICKSTART.md`: クイックスタートガイド
  - [x] `docs/IMPLEMENTATION_GUIDE.md`: 実装詳細
  - [x] `docs/TESTING.md`: テストガイド
  - [x] `CONTRIBUTING.md`: 貢献ガイド

- [x] **テストスクリプト**
  - [x] `scripts/test-local.sh`: ローカル統合テスト

## 動作確認チェックリスト

### 前提条件の確認

- [ ] Azure CLI がインストールされている
- [ ] Node.js 20+ がインストールされている
- [ ] Python 3.11+ がインストールされている
- [ ] Azure Functions Core Tools がインストールされている
- [ ] Azure サブスクリプションへのアクセスがある
- [ ] Azure AD アプリが登録されている

### デプロイの確認

- [ ] `./scripts/deploy-infra.sh` が成功
- [ ] `./scripts/deploy-function.sh` が成功
- [ ] `./scripts/create_agent.py` が成功
- [ ] `./scripts/deploy-webapp.sh` が成功
- [ ] `deployment-outputs.json` が生成されている
- [ ] `agent-config.json` が生成されている

### 機能テスト

- [ ] **テスト 1**: APIM に認証なしでリクエスト → 401
  ```bash
  curl -X POST $(jq -r '.apimMcpEndpoint' deployment-outputs.json) \
    -d '{}' -w "\nStatus: %{http_code}\n"
  ```
  期待: `Status: 401`

- [ ] **テスト 2**: APIM に認証ありでリクエスト → 成功
  ```bash
  TOKEN=$(az account get-access-token --resource "api://$(jq -r '.clientId' deployment-outputs.json)" --query accessToken -o tsv)
  curl -X POST $(jq -r '.apimMcpEndpoint' deployment-outputs.json) \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"method":"tools/list","id":"1"}' | jq .
  ```
  期待: ツールのリストが返される

- [ ] **テスト 3**: Web UI でログイン → チャット可能
  1. Web App URL にアクセス
  2. Microsoft でログイン
  3. "What's the weather in Tokyo?" と送信
  4. 応答を確認

- [ ] **テスト 4**: 異なるユーザーで結果が変わる
  1. ユーザー A でログイン → 応答を記録
  2. ログアウト
  3. ユーザー B でログイン → 応答を記録
  4. 温度単位が異なることを確認

### セキュリティチェック

- [ ] すべてのエンドポイントが HTTPS
- [ ] JWT 検証が機能している
- [ ] Function キーが適切に保護されている
- [ ] 環境変数に秘密情報が含まれていない（コード内）
- [ ] CORS 設定が適切

## 問題が見つかった場合

問題が見つかった場合は、以下を確認：

1. **ログの確認**
   ```bash
   # Function App のログ
   az webapp log tail -n $(jq -r '.functionName' deployment-outputs.json) -g $(jq -r '.resourceGroup' deployment-outputs.json)
   
   # Web App のログ
   az webapp log tail -n $(jq -r '.webAppName' deployment-outputs.json) -g $(jq -r '.resourceGroup' deployment-outputs.json)
   ```

2. **Application Insights**
   - Azure Portal で Application Insights を開く
   - ログとトレースを確認

3. **APIM トレース**
   - APIM ポータルで Test タブを開く
   - トレースを有効化してリクエスト

## 完了基準

すべての ✅ チェックボックスにチェックが入り、動作確認が完了したら、このイシューは完了です。

---

**Note**: このチェックリストは、実装の進捗管理と受け入れテストの両方に使用できます。
