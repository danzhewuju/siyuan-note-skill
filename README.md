# siyuan-note skill · 思源笔记技能

A portable Agent Skill that lets an AI coding agent (Claude Code, Cursor,
custom agents, …) search, read, summarize and create notes in your local
[SiYuan Note (思源笔记)](https://b3log.org/siyuan/) workspace through its
HTTP API.

一个可移植的 Agent Skill,让 AI 编程助手(Claude Code、Cursor、自定义 agent
等)通过 HTTP API 搜索、阅读、总结、创建你本地
[思源笔记](https://b3log.org/siyuan/) 工作区中的笔记。

> Language jump · 语言跳转:[English](#english) · [中文](#中文)

---

## English

### What is this?

This repository is a single [Agent Skill](https://docs.claude.com/en/docs/claude-code/skills)
folder containing:

| File | Purpose |
|------|---------|
| `SKILL.md` | Skill manifest + instructions the agent reads when the skill is triggered |
| `scripts/siyuan.sh` | Bash CLI that wraps the SiYuan HTTP API (`notebooks`, `docs`, `search`, `read`, `create`, `sql`, …) |
| `.env.example` | Template for local config – copy to `.env` and fill in your token |
| `.gitignore` | Keeps `.env` and local junk out of git |
| `LICENSE.txt` | License |
| `README.md` | This file – user-facing docs |

Once installed into your agent's skills directory, the agent will
automatically pick it up whenever you mention *SiYuan*, *思源*, *note*,
*笔记*, *search notes*, *summarize notes*, etc.

### Capabilities overview

1. **Connect & configure the SiYuan HTTP API**
   - Authenticates with `SIYUAN_TOKEN`.
   - `SIYUAN_URL` is optional, defaults to `http://127.0.0.1:6806`.
   - Auto-loads config from a `.env` file placed in the skill root.
   - Set `SIYUAN_SKIP_DOTENV=1` to disable automatic `.env` loading.

2. **List notebooks**
   - `siyuan.sh notebooks`
   - Returns each notebook's `id` and `name` (matches the `lsNotebooks`
     API response).

3. **Browse the document tree**
   - `siyuan.sh docs <notebook-id> [path]`
   - Inspect the document structure under a given path in a notebook;
     defaults to `/`.

4. **Search documents**
   - `siyuan.sh search <keyword> [limit]`
   - Searches document blocks only — best for finding a note by keyword.

5. **Search across all blocks**
   - `siyuan.sh search_blocks <keyword> [limit]`
   - Not restricted to documents; searches every block type for wider
     coverage.

6. **Read a document / block**
   - `siyuan.sh read <block-id>`
   - Returns the full Kramdown content.

7. **Create a Markdown document**
   - `siyuan.sh create <nb-id> <path> <markdown>`
   - Accepts content inline, or via stdin pipe for long text.
   - Creates a new document at the given `notebook/path`.

8. **Run SQL queries**
   - `siyuan.sh sql <statement>`
   - Query SiYuan's block DB directly — good for precise filters,
     aggregates, and stats.

9. **Built-in workflow support**
   - Search, then read a single note.
   - Search multiple notes, then synthesize a summary.
   - Pick a notebook first, then create a new document in it.
   - Walk the tree from a notebook's root, one level at a time.

10. **Conventions & capability boundaries**
    - The `id` field in `search` / `search_blocks` results **is** the
      block id — pass it straight into `read`.
    - `search` is limited to document blocks (`type='d'`);
      `search_blocks` covers every block type.
    - `create` paths are absolute **inside a notebook** and
      slash-separated, e.g. `/projects/foo/spec`.
    - `read` returns **Kramdown**; `create` accepts **Markdown**.
    - Tokens and URLs flow in via environment variables or `.env` only;
      never commit them, never paste them into shared prompts.

### Prerequisites

1. **SiYuan Note desktop app running locally** with its HTTP API enabled
   (it is enabled by default and listens on `http://127.0.0.1:6806`).
2. **An API token** from `Settings → About → API token` inside SiYuan.
3. `bash`, `curl`.
4. **`python3` or `jq`** — **required** for `create` (the script exits
   with an error if neither is present) and strongly recommended for
   `sql` (there is a fallback, but safe JSON escaping of the SQL text
   depends on one of them).

### Installation

Drop the whole folder into the skills directory of your agent. For
example:

```bash
# Claude Code – user-level skill
mkdir -p ~/.claude/skills
cp -r /path/to/siyuan-note-skill ~/.claude/skills/siyuan-note

# Cursor – user-level skill
mkdir -p ~/.cursor/skills
cp -r /path/to/siyuan-note-skill ~/.cursor/skills/siyuan-note
```

> Rename the folder to `siyuan-note` so it matches the `name` field in
> `SKILL.md` frontmatter. Keep the file layout (`SKILL.md`,
> `scripts/siyuan.sh`) exactly as shipped — the skill loader discovers
> `SKILL.md` by convention.

Make sure the script is executable:

```bash
chmod +x ~/.claude/skills/siyuan-note/scripts/siyuan.sh
```

### Configuration

The CLI needs two environment variables. Never commit real values.

| Variable | Required | Description |
|----------|----------|-------------|
| `SIYUAN_TOKEN` | Yes | API token from *Settings → About → API token* |
| `SIYUAN_URL`   | No  | Base URL of the API, default `http://127.0.0.1:6806` |

#### How to get an API token

1. Open the **SiYuan desktop app**.
2. Click the settings gear at the top-right to open **Settings**.
3. Go to **About**. The field **API token** is near the bottom.
4. Click the copy button. If the field is empty or you want a fresh one,
   click the refresh icon to regenerate it, then copy the new value.
5. For local use on `127.0.0.1:6806` the API works out of the box. If
   you want to reach it from another host, enable **Network serving** in
   SiYuan settings.

#### Pick one of these patterns

1. **Shell export** (quick / CI):

   ```bash
   export SIYUAN_TOKEN="your-token-here"
   export SIYUAN_URL="http://127.0.0.1:6806"   # optional
   ```

2. **Local `.env`** (personal dev, recommended):

   The repo ships an `.env.example`. Copy it into the skill folder and
   fill in your token — the script auto-sources `.env` unless
   `SIYUAN_SKIP_DOTENV=1` is set.

   ```bash
   cd ~/.claude/skills/siyuan-note       # or your Cursor skill path
   cp .env.example .env
   $EDITOR .env                          # paste the token
   ```

   `.env` is git-ignored (see `.gitignore`).

3. **Secret manager**: macOS Keychain, `op run --` (1Password CLI),
   `gopass`, etc. Export the variables into the environment before the
   agent launches.

### Usage

#### A. Let the agent use it (recommended)

Just talk to the agent in natural language. The skill's description
triggers on SiYuan / 思源 / note / 笔记 keywords. Examples:

- "搜一下我笔记里关于 Kafka 的内容,挑 3 条总结一下。"
- "List my SiYuan notebooks and show the 5 most recently updated docs."
- "把下面这段会议纪要存到思源里,放在 `/work/meetings/2026-04-24`。"

The agent will invoke `scripts/siyuan.sh` under the hood.

#### B. Use the CLI directly

From the skill folder:

```bash
./scripts/siyuan.sh                       # print help

./scripts/siyuan.sh notebooks             # list notebooks
./scripts/siyuan.sh docs <nb-id> /        # list docs at root
./scripts/siyuan.sh search "kafka" 10     # full-text search (docs only)
./scripts/siyuan.sh search_blocks "TODO"  # search all blocks
./scripts/siyuan.sh read <block-id>       # dump Kramdown of a doc/block

# Create a document – inline content
./scripts/siyuan.sh create <nb-id> "/inbox/hello" "# Hello\n\nBody"

# Create a document – piped (better for long / multiline content)
cat <<'EOF' | ./scripts/siyuan.sh create <nb-id> "/inbox/hello" -
# Hello

Body…
EOF

# Raw SQL against the SiYuan DB
./scripts/siyuan.sh sql "SELECT * FROM blocks WHERE type='d' ORDER BY updated DESC LIMIT 5"
```

All responses are JSON. Pipe to `jq` for readability:

```bash
./scripts/siyuan.sh notebooks | jq
```

### Command reference

| Command | Purpose |
|---------|---------|
| `notebooks` | List notebooks (id + name) |
| `docs <nb-id> [path]` | Walk the document tree (path defaults to `/`) |
| `search <keyword> [limit]` | Full-text search restricted to document blocks (`type='d'`) |
| `search_blocks <keyword> [limit]` | Full-text search over **every** block type |
| `read <block-id>` | Fetch Kramdown content of a doc/block |
| `create <nb-id> <path> <markdown>` | Create a Markdown document (use `-` to read content from stdin) |
| `sql <statement>` | Execute raw SQL against SiYuan's block DB |

Paths for `create` are absolute **within the notebook** and
slash-separated, e.g. `/projects/foo/spec`.

### Typical workflows

1. **Search → read → summarize**

   `search` → pick ids → `read` each → the agent writes a summary.

2. **Create a structured note**

   `notebooks` → pick notebook id → draft Markdown → `create`.

3. **Browse**

   `notebooks` → `docs <id> /` → `docs <id> /subfolder` → …

4. **Power-user analytics**

   ```sql
   -- 20 most recently updated docs
   SELECT * FROM blocks WHERE type='d' ORDER BY updated DESC LIMIT 20;

   -- Docs in a specific notebook
   SELECT * FROM blocks WHERE box='<notebook-id>' AND type='d'
     ORDER BY updated DESC;

   -- Count docs per notebook
   SELECT box, COUNT(*) AS c FROM blocks WHERE type='d' GROUP BY box;
   ```

### Troubleshooting

| Symptom | Likely cause / fix |
|---------|--------------------|
| `{"error":"SIYUAN_TOKEN is not set..."}` | Export `SIYUAN_TOKEN` or create `.env` in the skill root |
| `curl: (7) Failed to connect` | SiYuan desktop not running, or API bound to a different URL/port |
| `{"code":-1,"msg":"Auth failed"...}` | Token is wrong or was regenerated – copy a fresh one from Settings |
| `python3 or jq required for safe JSON encoding` | Install one of them – required by `create` and `sql` |
| Agent doesn't pick up the skill | Wrong folder location or folder name doesn't match `name:` in `SKILL.md` |

### Security notes

- The token grants full read/write access to your notes. Keep it local.
- Never commit `.env` or paste the token into prompts you share.
- Prefer a per-skill `.env` or a system secret store over global shell
  exports if multiple users share the machine.

### License

See [`LICENSE.txt`](./LICENSE.txt).

---

## 中文

### 这是什么?

本仓库是一个完整的 [Agent Skill](https://docs.claude.com/en/docs/claude-code/skills)
目录,包含:

| 文件 | 作用 |
|------|------|
| `SKILL.md` | 技能清单 + 触发时给 agent 的说明 |
| `scripts/siyuan.sh` | 封装思源 HTTP API 的 Bash 命令行(`notebooks`、`docs`、`search`、`read`、`create`、`sql` 等) |
| `.env.example` | 本地配置模板,复制为 `.env` 并填入 token |
| `.gitignore` | 让 `.env` 和本地杂项不要进 git |
| `LICENSE.txt` | 许可证 |
| `README.md` | 当前文档,面向用户 |

把这个目录装进你 agent 的 skills 目录后,当你聊天中提到
*思源*、*SiYuan*、*笔记*、*搜笔记*、*总结笔记* 等关键词,agent 会自动加载
`SKILL.md` 并使用 `scripts/siyuan.sh`。

### 功能清单

1. **连接和配置 SiYuan HTTP API**
   - 通过 `SIYUAN_TOKEN` 认证。
   - 可选 `SIYUAN_URL`,默认是 `http://127.0.0.1:6806`。
   - 支持从 skill 目录下的 `.env` 自动加载配置。
   - 可用 `SIYUAN_SKIP_DOTENV=1` 禁用 `.env` 自动加载。

2. **列出笔记本**
   - `siyuan.sh notebooks`
   - 返回每个笔记本的 `id` 和 `name`(与 `lsNotebooks` API 响应字段一致)。

3. **浏览文档树**
   - `siyuan.sh docs <notebook-id> [path]`
   - 查看某个笔记本下指定路径的文档结构,默认从 `/` 开始。

4. **搜索文档**
   - `siyuan.sh search <keyword> [limit]`
   - 只搜索文档块,适合按关键词找笔记。

5. **搜索所有块**
   - `siyuan.sh search_blocks <keyword> [limit]`
   - 不限于文档块,会搜索所有 block 类型,范围更广。

6. **读取文档 / 块内容**
   - `siyuan.sh read <block-id>`
   - 读取完整内容,返回 Kramdown。

7. **创建 Markdown 文档**
   - `siyuan.sh create <nb-id> <path> <markdown>`
   - 支持直接传内容,也支持从 stdin 管道输入长文本。
   - 本质上是往指定 notebook/path 创建新文档。

8. **执行 SQL 查询**
   - `siyuan.sh sql <statement>`
   - 可直接查 SiYuan 数据库,适合做精确筛选、聚合、统计。

9. **内置工作流支持**
   - 搜索后读取单篇笔记。
   - 搜索多篇笔记后做汇总 / 总结。
   - 先选 notebook 再创建新文档。
   - 从 notebook 根路径逐层浏览结构。

10. **使用约定和能力边界**
    - `search` / `search_blocks` 返回结果里的 `id` 字段就是 block id,
      可直接作为 `read` 的参数。
    - `search` 只搜文档块(`type='d'`);`search_blocks` 覆盖所有块类型。
    - `create` 的路径是 **笔记本内** 的绝对路径,`/` 分隔,例如
      `/projects/foo/spec`。
    - `read` 返回 **Kramdown**;`create` 接受 **Markdown**。
    - token 和 URL 只通过环境变量或 `.env` 注入,不入库、不粘贴到共享
      的 prompt 里。

### 前置条件

1. 本地开着 **思源笔记桌面端**,并保持 HTTP API 可访问(默认就开,监听
   `http://127.0.0.1:6806`)。
2. 在思源里 **设置 → 关于 → API token** 复制一个 **API token**。
3. 系统有 `bash`、`curl`。
4. **`python3` 或 `jq`** —— `create` 是 **硬依赖**(两者都缺脚本会直接
   报错退出),`sql` 强烈推荐(有简易兜底,但用它们做 JSON 转义才安全)。

### 安装

把整个目录复制到 agent 的 skills 目录:

```bash
# Claude Code 用户级 skill
mkdir -p ~/.claude/skills
cp -r /path/to/siyuan-note-skill ~/.claude/skills/siyuan-note

# Cursor 用户级 skill
mkdir -p ~/.cursor/skills
cp -r /path/to/siyuan-note-skill ~/.cursor/skills/siyuan-note
```

> 目录名最好就叫 `siyuan-note`,跟 `SKILL.md` 里的 `name:` 字段保持一致。
> 不要改文件结构(`SKILL.md` 必须在根,脚本在 `scripts/siyuan.sh`),
> skill 加载器是按约定找 `SKILL.md` 的。

确认脚本可执行:

```bash
chmod +x ~/.claude/skills/siyuan-note/scripts/siyuan.sh
```

### 配置

脚本需要两个环境变量,**真实 token 永远不要提交到 git**。

| 变量 | 是否必填 | 说明 |
|------|----------|------|
| `SIYUAN_TOKEN` | 必填 | 思源 *设置 → 关于 → API token* 里的值 |
| `SIYUAN_URL`   | 选填 | API 基地址,默认 `http://127.0.0.1:6806` |

#### 如何拿到 API token

1. 打开 **思源笔记桌面端**。
2. 点击右上角齿轮进入 **设置**。
3. 进入 **关于** 面板,往下翻到 **API token** 字段。
4. 点击复制按钮;如果字段是空的或者想换一个,点刷新图标重新生成再复制。
5. 本机用 `127.0.0.1:6806` 默认就能用;如果需要从其它机器访问 API,再
   到设置里打开 **网络服务**。

#### 三种配置方式任选一种

1. **Shell 临时导出**(临时用 / CI):

   ```bash
   export SIYUAN_TOKEN="your-token-here"
   export SIYUAN_URL="http://127.0.0.1:6806"   # 可省略
   ```

2. **本地 `.env`**(推荐日常使用):

   仓库自带 `.env.example`,复制到 skill 目录改一下就能用。脚本会自动
   加载 `.env`,如需临时禁用就设置 `SIYUAN_SKIP_DOTENV=1`。

   ```bash
   cd ~/.claude/skills/siyuan-note       # 或你 Cursor 的 skill 路径
   cp .env.example .env
   $EDITOR .env                          # 把 token 填进去
   ```

   `.env` 已在 `.gitignore` 中,不会进 git。

3. **系统密钥管理**:macOS Keychain、`op run --`(1Password CLI)、
   `gopass` 等,在启动 agent 前把变量注入环境即可。

### 使用

#### 方式 A:让 agent 自己用(推荐)

直接跟 agent 用自然语言说话就行。SKILL.md 的 description 会在命中关键词
时自动触发,例如:

- "搜一下我笔记里关于 Kafka 的内容,挑 3 条总结一下。"
- "列一下我的思源笔记本,再把最近更新的 5 篇文档列出来。"
- "把这份会议纪要保存到思源 `/work/meetings/2026-04-24`。"

Agent 会在后台调 `scripts/siyuan.sh`。

#### 方式 B:自己直接命令行调用

在 skill 目录下:

```bash
./scripts/siyuan.sh                       # 查看帮助

./scripts/siyuan.sh notebooks             # 列出所有笔记本
./scripts/siyuan.sh docs <笔记本id> /     # 列出根目录文档
./scripts/siyuan.sh search "kafka" 10     # 全文搜索(仅文档)
./scripts/siyuan.sh search_blocks "TODO"  # 搜索所有块
./scripts/siyuan.sh read <块id>           # 读取 Kramdown 内容

# 创建文档 – 内联内容
./scripts/siyuan.sh create <笔记本id> "/inbox/hello" "# Hello\n\n正文"

# 创建文档 – 通过管道(内容长 / 多行时更方便)
cat <<'EOF' | ./scripts/siyuan.sh create <笔记本id> "/inbox/hello" -
# 标题

正文…
EOF

# 直接跑 SQL
./scripts/siyuan.sh sql "SELECT * FROM blocks WHERE type='d' ORDER BY updated DESC LIMIT 5"
```

所有返回都是 JSON。建议管道到 `jq` 方便阅读:

```bash
./scripts/siyuan.sh notebooks | jq
```

### 命令速查

| 命令 | 作用 |
|------|------|
| `notebooks` | 列出所有笔记本(id + 名称) |
| `docs <笔记本id> [路径]` | 浏览文档树,默认 `/` |
| `search <关键词> [条数]` | 全文搜索,仅文档块(`type='d'`) |
| `search_blocks <关键词> [条数]` | 全文搜索所有类型的块 |
| `read <块id>` | 读取某个文档/块的 Kramdown 内容 |
| `create <笔记本id> <路径> <markdown>` | 创建 Markdown 文档(`-` 表示从标准输入读) |
| `sql <语句>` | 对思源块数据库执行原生 SQL |

`create` 的路径是 **笔记本内** 的绝对路径,用 `/` 分隔,例如
`/projects/foo/spec`。

### 常见工作流

1. **搜索 → 阅读 → 总结**

   `search` 拿到 id 列表 → 逐个 `read` → agent 汇总。

2. **创建结构化笔记**

   `notebooks` 挑笔记本 → 起草 Markdown → `create`。

3. **浏览目录**

   `notebooks` → `docs <id> /` → `docs <id> /子目录` → ……

4. **高阶查询**

   ```sql
   -- 最近更新的 20 篇文档
   SELECT * FROM blocks WHERE type='d' ORDER BY updated DESC LIMIT 20;

   -- 指定笔记本下的文档
   SELECT * FROM blocks WHERE box='<笔记本id>' AND type='d'
     ORDER BY updated DESC;

   -- 各笔记本文档数
   SELECT box, COUNT(*) AS c FROM blocks WHERE type='d' GROUP BY box;
   ```

### 排错

| 现象 | 可能原因 / 处理 |
|------|-----------------|
| `{"error":"SIYUAN_TOKEN is not set..."}` | 没导出 `SIYUAN_TOKEN`,或 skill 根目录下没 `.env` |
| `curl: (7) Failed to connect` | 思源桌面端没开,或 API 绑的不是默认地址 |
| `{"code":-1,"msg":"Auth failed"...}` | token 错了或者被重置,去设置里重新复制 |
| `python3 or jq required for safe JSON encoding` | `create`/`sql` 需要它们,装一个即可 |
| Agent 没触发 skill | 目录位置不对,或目录名与 `SKILL.md` 的 `name:` 不一致 |

### 安全提示

- API token 等同于对你的笔记有完整读写权限,请保存在本地。
- 不要把 `.env` 提交到 git;也不要在分享的对话里直接粘贴 token。
- 多人共用机器时,优先使用 skill 目录下的 `.env` 或系统密钥管理,而不
  是全局 shell 环境变量。

### 许可证

见 [`LICENSE.txt`](./LICENSE.txt)。
