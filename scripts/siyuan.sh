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

json_escape() {
    if command -v python3 &>/dev/null; then
        python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
    elif command -v jq &>/dev/null; then
        jq -Rs .
    else
        sed ':a;N;$!ba;s/\\/\\\\/g;s/"/\\"/g;s/\n/\\n/g' | sed '1s/^/"/;$s/$/"/'
    fi
}

emit_error() {
    local error_message="$1"
    local hint="${2:-}"
    local endpoint="${3:-}"
    local status_code="${4:-}"
    local details="${5:-}"

    local url_json
    local endpoint_json
    local error_json
    local hint_json
    local details_json

    url_json=$(printf '%s' "${SIYUAN_URL}" | json_escape)
    endpoint_json=$(printf '%s' "${endpoint}" | json_escape)
    error_json=$(printf '%s' "${error_message}" | json_escape)
    hint_json=$(printf '%s' "${hint}" | json_escape)
    details_json=$(printf '%s' "${details}" | json_escape)

    printf '{"error":%s,"url":%s' "${error_json}" "${url_json}" >&2
    if [ -n "${endpoint}" ]; then
        printf ',"endpoint":%s' "${endpoint_json}" >&2
    fi
    if [ -n "${status_code}" ]; then
        printf ',"status":%s' "${status_code}" >&2
    fi
    if [ -n "${details}" ]; then
        printf ',"details":%s' "${details_json}" >&2
    fi
    if [ -n "${hint}" ]; then
        printf ',"hint":%s' "${hint_json}" >&2
    fi
    printf '}\n' >&2
}

# Base API call function
api_call() {
    if [ -z "${SIYUAN_TOKEN}" ]; then
        emit_error \
            "SIYUAN_TOKEN is not set." \
            "Export SIYUAN_TOKEN before running this script. SIYUAN_URL is optional." \
            "$1"
        exit 1
    fi
    local endpoint="$1"
    local data="$2"
    local response_file
    local error_file
    local response_body
    local curl_error
    local http_code

    response_file=$(mktemp)
    error_file=$(mktemp)

    http_code=$(curl -sS -X POST \
        --connect-timeout 5 \
        --max-time 30 \
        -o "${response_file}" \
        -w "%{http_code}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Token ${SIYUAN_TOKEN}" \
        -d "${data}" \
        "${SIYUAN_URL}${endpoint}" 2>"${error_file}")
    local curl_status=$?

    response_body=$(cat "${response_file}")
    curl_error=$(tr '\n' ' ' < "${error_file}" | sed 's/[[:space:]]\+/ /g;s/^ //;s/ $//')
    rm -f "${response_file}" "${error_file}"

    if [ "${curl_status}" -ne 0 ]; then
        emit_error \
            "Failed to connect to SiYuan API." \
            "If this is running inside Codex, rerun the command with sandbox_permissions=require_escalated because siyuan.sh uses the SiYuan HTTP API." \
            "${endpoint}" \
            "" \
            "${curl_error}"
        exit "${curl_status}"
    fi

    if [ "${http_code}" -lt 200 ] || [ "${http_code}" -ge 300 ]; then
        emit_error \
            "SiYuan API returned a non-success status." \
            "Verify SIYUAN_URL, SIYUAN_TOKEN, and that the SiYuan API endpoint is reachable." \
            "${endpoint}" \
            "${http_code}" \
            "${response_body}"
        exit 1
    fi

    printf '%s\n' "${response_body}"
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

# Get full document tree across all notebooks
# Usage: tree
cmd_tree() {
    python3 -c "
import json, os, sys, urllib.request

url = os.environ.get('SIYUAN_URL', 'http://127.0.0.1:6806')
token = os.environ.get('SIYUAN_TOKEN', '')

if not token:
    print(json.dumps({'error': 'SIYUAN_TOKEN is not set'}), file=sys.stderr)
    sys.exit(1)

def api(endpoint, data):
    req = urllib.request.Request(
        f'{url}{endpoint}',
        data=json.dumps(data).encode(),
        headers={
            'Content-Type': 'application/json',
            'Authorization': f'Token {token}'
        }
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())

def get_tree(notebook_id, path='/'):
    result = api('/api/filetree/listDocsByPath', {'notebook': notebook_id, 'path': path})
    files = []
    for f in result['data']['files']:
        node = {
            'name': f['name'],
            'id': f['id'],
            'path': f['path'],
            'subFileCount': f.get('subFileCount', 0)
        }
        if node['subFileCount'] > 0:
            try:
                node['children'] = get_tree(notebook_id, f['path'])
            except Exception:
                node['children'] = []
        files.append(node)
    return files

try:
    notebooks_data = api('/api/notebook/lsNotebooks', {})
    notebooks = []
    for nb in notebooks_data['data']['notebooks']:
        nb_node = {
            'name': nb['name'],
            'id': nb['id']
        }
        try:
            nb_node['children'] = get_tree(nb['id'])
        except Exception as e:
            nb_node['children'] = []
            nb_node['error'] = str(e)
        notebooks.append(nb_node)

    print(json.dumps({'notebooks': notebooks}, ensure_ascii=False, indent=2))
except Exception as e:
    print(json.dumps({'error': str(e)}, ensure_ascii=False), file=sys.stderr)
    sys.exit(1)
"
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
    tree)
        cmd_tree
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
        echo "  tree                               Get full document tree of all notebooks"
        echo "  docs <notebook-id> [path]          List documents in notebook"
        echo "  search <keyword> [limit]           Search documents by keyword"
        echo "  search_blocks <keyword> [limit]    Search all blocks by keyword"
        echo "  read <block-id>                    Read document/block content"
        echo "  create <nb-id> <path> <markdown>   Create document with Markdown"
        echo "  sql <statement>                    Execute raw SQL query"
        exit 1
        ;;
esac
