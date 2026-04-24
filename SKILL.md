---
name: siyuan-note
description: Search, read, summarize, and create notes in a local SiYuan Note (思源笔记) workspace over its HTTP API via scripts/siyuan.sh. Use when the user mentions SiYuan, 思源, SiYuan Note, 思源笔记, or asks to search / read / summarize / create notes (搜笔记 / 读笔记 / 总结笔记 / 写笔记 / 建笔记), browse notebooks (笔记本), or run SQL against an API-enabled SiYuan instance. Supports both English and Chinese users.
license: Complete terms in LICENSE.txt
---

# SiYuan Note (思源笔记)

## Overview · 概览

This skill teaches agents how to interact with [SiYuan Note](https://b3log.org/siyuan/) through its HTTP API: list notebooks, walk the document tree, full-text search, read Kramdown content, create Markdown documents, and run SQL when appropriate.

**中文概要**:通过 `scripts/siyuan.sh` 调用思源 HTTP API,完成笔记本列表、文档树浏览、搜索、阅读、创建与 SQL 查询等操作。

## Language · 语言

**Reply in the same language the user wrote in.**

- If the user writes in Chinese (e.g. "搜一下我笔记里关于 Kafka 的内容"), reply in Chinese. Quote note titles and excerpts in their original language — do not translate them unless the user asks.
- If the user writes in English, reply in English.
- Regardless of language, keep JSON payloads, command names, notebook ids, block ids, and file paths **verbatim** — never translate them.

**用户用什么语言提问,就用什么语言回复。**笔记标题和内容引用按原文保留,JSON / 命令 / id / 路径永远保持原样。

## Configuration · 配置

Never commit real tokens or private URLs. Prefer one of these patterns:

1. **Shell exports** (CI, ad-hoc): set variables for the process; they override any file.
2. **Local `.env`** (personal dev): copy `.env.example` to `.env` in this skill folder (`siyuan-note/.env`). The script auto-sources it unless `SIYUAN_SKIP_DOTENV=1`. `.env` is listed in `.gitignore`.
3. **Host secret store**: e.g. macOS Keychain, [1Password CLI](https://developer.1password.com/docs/cli/) (`op run --`), or your agent's secret injection — export into the environment before invoking the script.

| Variable | Required | Description · 说明 |
|----------|----------|--------------------|
| `SIYUAN_TOKEN` | Yes · 必填 | API token from SiYuan: **Settings → About → API token** · 思源 **设置 → 关于 → API token** |
| `SIYUAN_URL` | No · 选填 | Base URL of the SiYuan API, default `http://127.0.0.1:6806` · API 基地址,默认 `http://127.0.0.1:6806` |

Example (explicit exports):

```bash
export SIYUAN_URL="http://127.0.0.1:6806"
export SIYUAN_TOKEN="your-token-here"
```

Run the script from the skill root (or pass its absolute path). All commands print JSON; use `jq` for pretty output when available.

## Commands · 命令

| Command | Purpose · 作用 | Notes · 备注 |
|---------|----------------|--------------|
| `siyuan.sh notebooks` | List notebooks · 列出笔记本 | Returns each notebook's `id` + `name` · 返回 `id` 和 `name` |
| `siyuan.sh docs <notebook-id> [path]` | List document tree · 浏览文档树 | Path defaults to `/` · 默认根路径 `/` |
| `siyuan.sh search <keyword> [limit]` | Search documents · 搜索文档 (`type='d'`) | Keyword + optional limit · 关键词 + 可选条数 |
| `siyuan.sh search_blocks <keyword> [limit]` | Search all blocks · 搜索所有块 | Broader than `search` · 范围比 `search` 更广 |
| `siyuan.sh read <block-id>` | Read Kramdown · 读取 Kramdown | Use `id` from search results · id 来自搜索结果 |
| `siyuan.sh create <nb-id> <path> <markdown>` | Create Markdown doc · 创建 Markdown 文档 | Pipe long content with `-` as last arg · 长内容可用 `-` 从 stdin 读 |
| `siyuan.sh sql <statement>` | Run SQL · 执行 SQL | Advanced / precise queries · 精确筛选 / 聚合 |

## Workflows · 工作流

### 1. Search and read · 搜索并阅读

1. `siyuan.sh search "keyword"` — list matching documents (title, path, snippet).
2. Present results; let the user pick an item.
3. `siyuan.sh read <block-id>` — load full Kramdown for the chosen document.

- EN prompt: *"Find my notes about Kafka, then show me the top one."*
- 中文 prompt:*"搜一下我笔记里关于 Kafka 的内容,读一下最相关的那篇。"*

### 2. Summarize across notes · 跨笔记总结

1. `siyuan.sh search "topic"` — collect relevant document ids.
2. For each selected result, `siyuan.sh read <id>`.
3. Synthesize a concise report from the combined content, **in the user's language**.

- EN prompt: *"Summarize action items from my meeting notes this week."*
- 中文 prompt:*"帮我把这周的会议记录总结一下,挑出行动项。"*

### 3. Create a document · 创建文档

1. `siyuan.sh notebooks` — choose a notebook id.
2. Confirm notebook and path (paths start with `/`, segments separated by `/`, e.g. `/work/meetings/2024-01`).
3. Generate Markdown, then either:
   - `siyuan.sh create <notebook-id> "/path/title" "markdown..."`, or
   - pipe long content:

```bash
cat <<'EOF' | siyuan.sh create <notebook-id> "/path/title" -
# Title

Body…
EOF
```

- EN prompt: *"Save this spec to /projects/foo/spec in my Work notebook."*
- 中文 prompt:*"把这段内容存到我 Work 笔记本的 `/projects/foo/spec` 下。"*

### 4. Browse structure · 浏览目录结构

1. `siyuan.sh notebooks`
2. `siyuan.sh docs <notebook-id> /`
3. `siyuan.sh docs <notebook-id> /subfolder` to go deeper

## SQL examples · SQL 示例

SiYuan exposes a SQL API; prefer `search` / `read` unless the user needs aggregates or precise filters.

思源暴露了一个 SQL 接口,除非需要聚合或精确筛选,否则优先用 `search` / `read`。

```sql
-- Recently updated documents · 最近更新的文档
SELECT * FROM blocks WHERE type='d' ORDER BY updated DESC LIMIT 20;

-- Filter by tag · 按标签过滤
SELECT * FROM blocks WHERE tag LIKE '%tagname%';

-- Documents in one notebook · 某个笔记本下的文档
SELECT * FROM blocks WHERE box='notebook-id' AND type='d' ORDER BY updated DESC;

-- Count documents per notebook · 各笔记本的文档数量
SELECT box, COUNT(*) AS count FROM blocks WHERE type='d' GROUP BY box;
```

## Guidelines · 规则

1. **Language · 语言**: Reply in the user's language. Quote note content verbatim; do not translate titles/excerpts unless asked. · 跟随用户语言回复;笔记标题和正文按原文引用,不主动翻译。
2. **Block id**: The `id` field in search results is the block id for `read`. · 搜索结果里的 `id` 字段就是可传给 `read` 的 block id。
3. **Documents vs blocks**: `search` limits to document blocks (`type='d'`); `search_blocks` searches every block type. · `search` 只搜文档块,`search_blocks` 搜所有块。
4. **Paths**: Creation paths are absolute within the notebook, slash-separated, e.g. `/projects/foo/spec`. · `create` 的路径是笔记本内的绝对路径,`/` 分隔。
5. **Formats**: `read` returns Kramdown; `create` accepts Markdown. · `read` 返回 Kramdown,`create` 接受 Markdown。
6. **Safety · 安全**: Do not embed secrets in the skill or repo; use environment variables or `.env` only. Never echo the token back to the user. · 不要把 token 写进仓库,不要在回复里回显 token。

## Examples · 对话示例

English:

- "List my SiYuan notebooks and show the 5 most recently updated docs."
- "Find all meeting notes from last week and summarize action items."
- "Create `/projects/foo/spec` in my Work notebook with this content: …"

中文:

- "列一下我的思源笔记本,再把最近更新的 5 篇文档列出来。"
- "搜一下我思源里上周的会议记录,帮我提炼行动项。"
- "在我的 Work 笔记本下新建 `/projects/foo/spec`,内容如下……"

## Contributing this folder upstream · 向上游贡献

To propose this skill to [anthropics/skills](https://github.com/anthropics/skills), add it as **`skills/siyuan-note/`** in that repository (same layout as here: `SKILL.md`, `LICENSE.txt`, `scripts/siyuan.sh`), keep frontmatter to `name`, `description`, and optional `license`, and confirm there are **no** committed credentials.

如需把本 skill 贡献到 [anthropics/skills](https://github.com/anthropics/skills),请保持目录结构(`SKILL.md`、`LICENSE.txt`、`scripts/siyuan.sh`),frontmatter 仅保留 `name`、`description`、`license`,并**确认没有任何凭据被提交**。
