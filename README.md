# Taskail ローカルワーカー

[Taskail](https://github.com/take-p/taskail) のタスクを AI に依頼したときに、
**手元のマシンで `claude -p` を起動する**常駐プロセスの配布先です。

このリポジトリにあるのは配布物と取得手順だけで、ソースは本体（非公開）にあります。

## 前提

- `claude` が入っていて、サブスクでログイン済み
- Taskail の MCP サーバーが `claude mcp add` で登録済み（`/mcp` で認可まで済ませておく）

**AI の実行コストは、あなた自身の Claude サブスクが負担します。**
Taskail のサーバーは Anthropic の API キーを持ちません。

## 入れかた

```sh
curl -fsSL https://raw.githubusercontent.com/take-p/taskail-worker/main/install.sh | sh
```

`~/.local/bin/taskail-worker` に入ります。Node は要りません（単一バイナリ）。
落としたものは SHA256 を照合してから置きます。

### 1. ログインする

```sh
taskail-worker login
```

メールアドレスとパスワードを聞かれます。**パスワードは保存されません。**
交換して得た refresh token だけが `~/.taskail/credentials.json` に 0600 で置かれます。

### 2. `~/.taskail/config.json` を書く

マシンごとに違う情報（作業ディレクトリのパスなど）はサーバーに持たせず、ここに置きます。

```json
{
  "workerName": "MacBook",
  "mcp": {
    "server": "taskail",
    "url": "https://<Taskail のドメイン>/api/mcp"
  },
  "claude": {
    "permissionMode": "acceptEdits"
  },
  "projects": [
    { "projectId": "<Taskail のプロジェクト ID>", "path": "~/projects/myrepo" }
  ],
  "defaultPath": "~/.taskail/workspaces"
}
```

| キー | 既定 | 意味 |
| --- | --- | --- |
| `workerName` | ホスト名 | 画面に出す名前 |
| `workerId` | 自動生成 | **手で書かない。** 初回起動時に書き戻されます |
| `mcp.server` | `taskail` | `claude mcp add` で付けた名前と**必ず一致させる**。ずれると OAuth を引けず未認可になります |
| `mcp.url` | 必須 | Taskail の `<origin>/api/mcp` |
| `mcp.strict` | `true` | 他の MCP を混ぜない |
| `claude.model` | 未指定 | `claude --model` に渡す |
| `claude.permissionMode` | `acceptEdits` | **`manual` にしないこと**（ヘッドレスで必ず固まります） |
| `claude.allowedTools` | Read/Edit/Write/Glob/Grep/Bash/**WebSearch** + `mcp__<server>__*` | **自動承認する一覧**です（使えるツールの制限ではありません）。**書くと既定が丸ごと置き換わる**ので `mcp__<server>__*` を必ず含めてください。`WebFetch` は既定に含みません（無人実行では、取得先のページに書かれた指示を読んでしまう経路になるため） |
| `claude.timeoutMinutes` | `60` | 1回の実行の上限（分）。`0` で無制限 |
| `projects[]` | 必須 | **ファイルが手元にある**プロジェクトの申告。`defaultPath` があれば空でもよい |
| `projects[].path` | 必須 | 作業ディレクトリ。**git リポジトリのルートを指すと worktree で隔離されます** |
| `defaultPath` | なし | リポジトリを持たないプロジェクト用の作業ディレクトリの根。書くと申告外の依頼も引き受けます |
| `maxConcurrent` | `10` | 同時に実行する数の上限。マシンのメモリが足りなければ、これより少なく抑えます |
| `logRetentionDays` | `14` | 生ログ（`~/.taskail/logs/`）を残す日数。`0` で消さない |

**手元にファイルが無いプロジェクトを `projects[]` に書かないでください。**
他のワーカーはこの申告を見て「そちらが担当する」と判断します。

### 3. 起動する

```sh
taskail-worker start
```

待機に入ります。タスクかプロジェクトのチャットで**人間が** AI をメンションすると起動します
（`@<モデル ID>` か `@sonnet` のような別名で呼びます。担当者を AI にするだけでは動きません）。

## 動きかた

- **複数の依頼を同時に実行します。** 既定は最大10件で、マシンのメモリに合わせて自動で抑えます。
  タスクごとに worktree が分かれているためで、同じタスクの依頼は並べません
- **モデルは依頼で呼ばれたものを使います。** 使えるモデルは `claude` から取って Taskail に申告し
  （起動時と、その後も定期的に）、画面の候補に出ます
- **git リポジトリのルートで動くときは、作業ブランチにコミットして origin に push します。**
  main への push と Pull Request は行いません。プロジェクトの「高度な設定」で
  「ワーカーに main へのマージと push を許可」をオンにすると、作業を終えて検証が済んだら
  main に取り込んで push します（force push はしません）
- **失敗してもリトライしません。** 理由をタスクチャットに書き、ステータスを「問題発生」にします
- 生の実行ログは `~/.taskail/logs/<日付>/` に残ります。**サーバーには送りません**
  （ファイルの中身が混ざるため）。既定14日で消えます
- 実行中に `claude` から届くサブスクの利用枠（5時間枠・7日枠の使用率）は Taskail に送り、画面に出します
- 実行は `claude --resume <session id>` で辿れます

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

## ワーカーの環境変数

| | |
| --- | --- |
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` | 接続先。バイナリに焼き込んだ既定値を上書きします（自分で Taskail を立てた場合） |
| `TASKAIL_HOME` | 設定・資格情報・ログの置き場所（既定 `~/.taskail`）。1台で複数立てるときに分けます |
