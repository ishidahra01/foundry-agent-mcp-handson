# Contributing to Foundry MCP Handson

このプロジェクトへの貢献を歓迎します！

## 開発環境のセットアップ

### 必要なツール

- Azure CLI (v2.50.0+)
- Node.js (v20+)
- Python (v3.11+)
- Azure Functions Core Tools (v4+)
- Git

### ローカルセットアップ

```bash
# リポジトリをクローン
git clone https://github.com/ishidahra01/foundry-agent-mcp-handson.git
cd foundry-agent-mcp-handson

# MCP Server のセットアップ
cd mcp-server
pip install -r requirements.txt
cd ..

# Web App のセットアップ
cd webapp
npm install
cd ..
```

## 開発フロー

### 1. ブランチを作成

```bash
git checkout -b feature/your-feature-name
```

### 2. 変更を加える

- コードスタイル: 既存のコードに合わせる
- コメント: 日本語または英語
- テスト: 新機能には必ずテストを追加

### 3. ローカルテスト

```bash
# MCP Server のテスト
cd mcp-server
func start

# 別のターミナルで
./scripts/test-local.sh
```

### 4. コミット

```bash
git add .
git commit -m "Add: 新機能の説明"
```

コミットメッセージの規約:
- `Add:` 新機能追加
- `Fix:` バグ修正
- `Update:` 既存機能の更新
- `Docs:` ドキュメント変更
- `Refactor:` リファクタリング

### 5. プルリクエスト

```bash
git push origin feature/your-feature-name
```

GitHub でプルリクエストを作成してください。

## コーディング規約

### Python (MCP Server)

- PEP 8 に従う
- 型ヒントを使用
- Docstring を追加

```python
def get_weather_result(city: str, user_id: str) -> Dict[str, Any]:
    """
    Get weather information for a city.
    
    Args:
        city: The city name
        user_id: The user identifier
        
    Returns:
        Dictionary with weather information
    """
    pass
```

### TypeScript (Web App)

- TypeScript strict mode
- 関数には型を明示

```typescript
async function sendMessage(message: string): Promise<void> {
  // implementation
}
```

### Bicep (Infrastructure)

- パラメータに説明を追加
- リソース名は明確に

```bicep
@description('Location for all resources')
param location string = 'japaneast'
```

## テスト

### ユニットテスト

将来的に追加予定

### 統合テスト

```bash
./scripts/test-local.sh
```

## ドキュメント

新機能を追加する場合は、以下のドキュメントを更新してください：

- `README.md`: 主要な機能
- `docs/IMPLEMENTATION_GUIDE.md`: 実装詳細
- `docs/TESTING.md`: テスト方法

## 質問やサポート

- GitHub Issues で質問してください
- バグレポートは詳細な再現手順を含めてください

## ライセンス

このプロジェクトは MIT ライセンスです。貢献したコードも MIT ライセンスの下で公開されます。
