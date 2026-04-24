#!/bin/bash
# SiYuan Note API CLI
# Usage: siyuan.sh <command> [args...]
#
# Configuration (required for API calls):
#   SIYUAN_TOKEN  API token from SiYuan: Settings → About → API token
#   SIYUAN_URL    Base URL of the SiYuan HTTP API (default: http://127.0.0.1:6806)
#
# Precedence: environment variables win. Optionally copy ../.env.example to ../.env
# (gitignored) so local values load automatically. Set SIYUAN_SKIP_DOTENV=1 to
# disable loading ../.env.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [ -z "${SIYUAN_SKIP_DOTENV:-}" ] && [ -f "${SKILL_ROOT}/.env" ]; then
    set -a
    # shellcheck source=/dev/null
    source "${SKILL_ROOT}/.env"
    set +a
fi

SIYUAN_URL="${SIYUAN_URL:-http://127.0.0.1:6806}"
SIYUAN_TOKEN="${SIYUAN_TOKEN:-}"

# Base API call function
api_call() {
    if [ -z "${SIYUAN_TOKEN}" ]; then
        echo '{"error":"SIYUAN_TOKEN is not set. Export SIYUAN_TOKEN (and optionally SIYUAN_URL) before running this script."}' >&2
        exit 1
    fi
    local endpoint="$1"
    local data="$2"
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Token ${SIYUAN_TOKEN}" \
        -d "${data}" \
        "${SIYUAN_URL}${endpoint}"
}

# List all notebooks
cmd_notebooks() {
    api_call "/api/notebook/lsNotebooks" "{}"
}

# List documents by path
# Usage: docs <notebook-id> [path]
cmd_docs() {
    local notebook="$1"
    local path="${2:-/}"
    if [ -z "$notebook" ]; then
        echo "Usage: siyuan.sh docs <notebook-id> [path]"
        exit 1
    fi
    api_call "/api/filetree/listDocsByPath" "{\"notebook\":\"${notebook}\",\"path\":\"${path}\"}"
}

# Search notes by keyword (SQL full-text search)
# Usage: search <keyword> [limit]
cmd_search() {
    local keyword="$1"
    local limit="${2:-20}"
    if [ -z "$keyword" ]; then
        echo "Usage: siyuan.sh search <keyword> [limit]"
        exit 1
    fi
    # Escape single quotes in keyword
    local safe_keyword="${keyword//\'/\'\'}"
    local sql="SELECT * FROM blocks WHERE content LIKE '%${safe_keyword}%' AND type='d' ORDER BY updated DESC LIMIT ${limit}"
    api_call "/api/query/sql" "{\"stmt\":\"${sql}\"}"
}

# Search blocks (not just documents)
# Usage: search_blocks <keyword> [limit]
cmd_search_blocks() {
    local keyword="$1"
    local limit="${2:-20}"
    if [ -z "$keyword" ]; then
        echo "Usage: siyuan.sh search_blocks <keyword> [limit]"
        exit 1
    fi
    local safe_keyword="${keyword//\'/\'\'}"
    local sql="SELECT * FROM blocks WHERE content LIKE '%${safe_keyword}%' ORDER BY updated DESC LIMIT ${limit}"
    api_call "/api/query/sql" "{\"stmt\":\"${sql}\"}"
}

# Read document content (Kramdown format)
# Usage: read <block-id>
cmd_read() {
    local block_id="$1"
    if [ -z "$block_id" ]; then
        echo "Usage: siyuan.sh read <block-id>"
        exit 1
    fi
    api_call "/api/block/getBlockKramdown" "{\"id\":\"${block_id}\"}"
}

# Create a document with Markdown content
# Usage: create <notebook-id> <path> <markdown-content>
# Or pipe: echo "content" | siyuan.sh create <notebook-id> <path> -
cmd_create() {
    local notebook="$1"
    local doc_path="$2"
    local markdown="$3"
    if [ -z "$notebook" ] || [ -z "$doc_path" ]; then
        echo "Usage: siyuan.sh create <notebook-id> <path> <markdown-content>"
        echo "       echo 'content' | siyuan.sh create <notebook-id> <path> -"
        exit 1
    fi
    # Support reading from stdin
    if [ "$markdown" = "-" ]; then
        markdown=$(cat)
    fi
    # Use python/jq to properly escape JSON
    local json
    if command -v python3 &>/dev/null; then
        json=$(python3 -c "
import json, sys
print(json.dumps({
    'notebook': sys.argv[1],
    'path': sys.argv[2],
    'markdown': sys.argv[3]
}))" "$notebook" "$doc_path" "$markdown")
    elif command -v jq &>/dev/null; then
        json=$(jq -n \
            --arg nb "$notebook" \
            --arg p "$doc_path" \
            --arg md "$markdown" \
            '{notebook: $nb, path: $p, markdown: $md}')
    else
        echo "Error: python3 or jq required for safe JSON encoding"
        exit 1
    fi
    api_call "/api/filetree/createDocWithMd" "$json"
}

# Execute raw SQL query
# Usage: sql <statement>
cmd_sql() {
    local stmt="$1"
    if [ -z "$stmt" ]; then
        echo "Usage: siyuan.sh sql <sql-statement>"
        exit 1
    fi
    local json
    if command -v python3 &>/dev/null; then
        json=$(python3 -c "
import json, sys
print(json.dumps({'stmt': sys.argv[1]}))" "$stmt")
    elif command -v jq &>/dev/null; then
        json=$(jq -n --arg s "$stmt" '{stmt: $s}')
    else
        # Fallback: basic escaping
        local safe_stmt="${stmt//\\/\\\\}"
        safe_stmt="${safe_stmt//\"/\\\"}"
        json="{\"stmt\":\"${safe_stmt}\"}"
    fi
    api_call "/api/query/sql" "$json"
}

# Main command dispatcher
case "${1}" in
    notebooks)
        cmd_notebooks
        ;;
    docs)
        cmd_docs "$2" "$3"
        ;;
    search)
        cmd_search "$2" "$3"
        ;;
    search_blocks)
        cmd_search_blocks "$2" "$3"
        ;;
    read)
        cmd_read "$2"
        ;;
    create)
        cmd_create "$2" "$3" "$4"
        ;;
    sql)
        cmd_sql "$2"
        ;;
    *)
        echo "SiYuan Note CLI"
        echo ""
        echo "Usage: siyuan.sh <command> [args...]"
        echo ""
        echo "Commands:"
        echo "  notebooks                          List all notebooks"
        echo "  docs <notebook-id> [path]          List documents in notebook"
        echo "  search <keyword> [limit]           Search documents by keyword"
        echo "  search_blocks <keyword> [limit]    Search all blocks by keyword"
        echo "  read <block-id>                    Read document/block content"
        echo "  create <nb-id> <path> <markdown>   Create document with Markdown"
        echo "  sql <statement>                    Execute raw SQL query"
        exit 1
        ;;
esac
