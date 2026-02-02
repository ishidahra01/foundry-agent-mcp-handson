# Flow① Implementation Guide

このガイドでは、Flow① の実装詳細と各コンポーネントの動作について説明します。

## アーキテクチャコンポーネント

### 1. Web App (Next.js)

#### ディレクトリ構造
```
webapp/
├── app/
│   ├── api/
│   │   └── chat/
│   │       └── route.ts        # Foundry Agent API エンドポイント
│   ├── MsalProvider.tsx        # MSAL 認証プロバイダー
│   ├── layout.tsx              # アプリケーションレイアウト
│   ├── page.tsx                # メインページ（チャット UI）
│   ├── globals.css             # グローバルスタイル
│   └── page.module.css         # ページ固有のスタイル
├── lib/
│   └── authConfig.ts           # MSAL 設定
├── package.json
├── tsconfig.json
└── next.config.js
```

#### 認証フロー

1. **ログイン**: ユーザーが「Sign In」ボタンをクリック
2. **MSAL Popup**: Microsoft 認証ポップアップが開く
3. **トークン取得**: 認証成功後、アクセストークンを取得
4. **セッション保存**: トークンを sessionStorage に保存
5. **API 呼び出し**: `/api/chat` にトークン付きでリクエスト

### 2. MCP Server (Azure Functions)

#### ユーザー固有のロジック

Function は `X-EndUser-Id` ヘッダーからユーザー ID を取得し、ハッシュ値に基づいて応答を変更します。

### 3. APIM Policy

APIM ポリシーは以下を実行：
1. JWT 検証
2. `oid` クレームの抽出
3. `X-EndUser-Id` ヘッダーの設定

## セキュリティ考慮事項

### JWT 検証
- issuer 検証
- audience 検証
- 署名検証

### HTTPS の強制
すべてのコンポーネントで HTTPS を強制

## トラブルシューティング

詳細は README.md を参照してください。
