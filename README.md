# Taskail ローカルワーカー

[Taskail](https://github.com/take-p/taskail) のタスクを AI に依頼したときに、
**手元のマシンで `claude -p` を起動する**常駐プロセスの配布先です。

このリポジトリにあるのは配布物と取得手順だけで、ソースは本体（非公開）にあります。

## 入れかた

```sh
curl -fsSL https://raw.githubusercontent.com/take-p/taskail-worker/main/install.sh | sh
```

`~/.local/bin/taskail-worker` に入ります。Node は要りません（単一バイナリ）。
落としたものは SHA256 を照合してから置きます。

```sh
taskail-worker login          # Taskail にログインする
taskail-worker start          # 待機に入る
```

間に `~/.taskail/config.json` を書く手順があります。

## 前提

- `claude` が入っていて、サブスクでログイン済み
- Taskail の MCP サーバーが `claude mcp add` で登録済み（`/mcp` で認可まで済ませておく）

**AI の実行コストは、あなた自身の Claude サブスクが負担します。**
Taskail のサーバーは Anthropic の API キーを持ちません。

## 対応プラットフォーム

| | |
| --- | --- |
| macOS | Apple Silicon のみ。**Intel Mac は非対応** |
| Linux | arm64 / x64。**`libatomic1` が要ります**（`sudo apt install libatomic1`） |

macOS のバイナリは ad-hoc 署名のみで公証していないため、Gatekeeper の警告が出ます。

## インストーラーの環境変数

| | |
| --- | --- |
| `TASKAIL_INSTALL_DIR` | 置き場所（既定 `~/.local/bin`）。sudo が要る場所なら sudo 付きで実行 |
| `TASKAIL_VERSION` | 版の固定（既定 `latest`）。例: `worker-v0.1.0` |
