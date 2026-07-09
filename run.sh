#!/bin/bash
#
# Docker script to configure and start a text embeddings server
#
# DO NOT RUN THIS SCRIPT ON YOUR PC OR MAC! THIS IS ONLY MEANT TO BE RUN
# IN A CONTAINER!
#
# This file is part of Embeddings Docker image, available at:
# https://github.com/hwdsl2/docker-embeddings
#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

export PATH="/opt/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

exiterr()  { echo "Error: $1" >&2; exit 1; }
nospaces() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
noquotes() { printf '%s' "$1" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"; }

check_port() {
  printf '%s' "$1" | tr -d '\n' | grep -Eq '^[0-9]+$' \
  && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

check_ip() {
  IP_REGEX='^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'
  printf '%s' "$1" | tr -d '\n' | grep -Eq "$IP_REGEX"
}

# Source bind-mounted env file if present (takes precedence over --env-file)
if [ -f /embed.env ]; then
  # shellcheck disable=SC1091
  . /embed.env
fi

if [ ! -f "/.dockerenv" ] && [ ! -f "/run/.containerenv" ] \
  && [ -z "$KUBERNETES_SERVICE_HOST" ] \
  && ! head -n 1 /proc/1/sched 2>/dev/null | grep -q '^run\.sh '; then
  exiterr "This script ONLY runs in a container (e.g. Docker, Podman)."
fi

EMBED_API_KEY_WAS_SET=${EMBED_API_KEY+x}
RERANK_API_KEY_WAS_SET=${RERANK_API_KEY+x}

# Read and sanitize environment variables
EMBED_MODEL=$(nospaces "$EMBED_MODEL")
EMBED_MODEL=$(noquotes "$EMBED_MODEL")
EMBED_PORT=$(nospaces "$EMBED_PORT")
EMBED_PORT=$(noquotes "$EMBED_PORT")
EMBED_API_KEY=$(nospaces "$EMBED_API_KEY")
EMBED_API_KEY=$(noquotes "$EMBED_API_KEY")
EMBED_HF_TOKEN=$(nospaces "$EMBED_HF_TOKEN")
EMBED_HF_TOKEN=$(noquotes "$EMBED_HF_TOKEN")
EMBED_LOCAL_ONLY=$(nospaces "$EMBED_LOCAL_ONLY")
EMBED_LOCAL_ONLY=$(noquotes "$EMBED_LOCAL_ONLY")
EMBED_ENABLED=$(nospaces "$EMBED_ENABLED")
EMBED_ENABLED=$(noquotes "$EMBED_ENABLED")

RERANK_ENABLED=$(nospaces "$RERANK_ENABLED")
RERANK_ENABLED=$(noquotes "$RERANK_ENABLED")
RERANK_MODEL=$(nospaces "$RERANK_MODEL")
RERANK_MODEL=$(noquotes "$RERANK_MODEL")
RERANK_PORT=$(nospaces "$RERANK_PORT")
RERANK_PORT=$(noquotes "$RERANK_PORT")
RERANK_API_KEY=$(nospaces "$RERANK_API_KEY")
RERANK_API_KEY=$(noquotes "$RERANK_API_KEY")

# Apply defaults
[ -z "$EMBED_MODEL" ] && EMBED_MODEL=BAAI/bge-small-en-v1.5
[ -z "$EMBED_PORT" ]  && EMBED_PORT=8000
[ -z "$RERANK_MODEL" ] && RERANK_MODEL=BAAI/bge-reranker-v2-m3

# Determine if embeddings is enabled (default: true)
embed_active=1
if [ "$EMBED_ENABLED" = "false" ] || [ "$EMBED_ENABLED" = "False" ] || [ "$EMBED_ENABLED" = "FALSE" ] || [ "$EMBED_ENABLED" = "0" ]; then
  embed_active=0
fi

# Determine if reranking is enabled (default: disabled)
rerank_active=0
if [ "$RERANK_ENABLED" = "true" ] || [ "$RERANK_ENABLED" = "True" ] || [ "$RERANK_ENABLED" = "TRUE" ] || [ "$RERANK_ENABLED" = "1" ]; then
  rerank_active=1
fi

# Validate at least one service is enabled
if [ "$embed_active" = 0 ] && [ "$rerank_active" = 0 ]; then
  exiterr "At least one service must be enabled. Set EMBED_ENABLED=true and/or RERANK_ENABLED=true."
fi

# Determine reranker port
if [ -z "$RERANK_PORT" ]; then
  if [ "$embed_active" = 0 ]; then
    RERANK_PORT=8000
  else
    RERANK_PORT=8001
  fi
fi

# Validate ports
if [ "$embed_active" = 1 ]; then
  if ! check_port "$EMBED_PORT"; then
    exiterr "EMBED_PORT must be an integer between 1 and 65535."
  fi
fi
if [ "$rerank_active" = 1 ]; then
  if ! check_port "$RERANK_PORT"; then
    exiterr "RERANK_PORT must be an integer between 1 and 65535."
  fi
fi

# Check port conflict
if [ "$embed_active" = 1 ] && [ "$rerank_active" = 1 ] && [ "$EMBED_PORT" = "$RERANK_PORT" ]; then
  exiterr "EMBED_PORT and RERANK_PORT cannot be the same (both set to $EMBED_PORT). Use different ports."
fi

mkdir -p /var/lib/embeddings

DATA_DIR="/var/lib/embeddings"
API_KEY_FILE="${DATA_DIR}/.api_key"
AUTO_API_KEY_MARKER="${DATA_DIR}/.auto_api_key_created"
USAGE_STATE_DIR="${DATA_DIR}/.embeddings-usage"
USAGE_BASE_URL=${EMBED_USAGE_BASE_URL:-https://github.com/hwdsl2/ai-stack-extras/releases/download/v1.0.0}
data_mounted=false
data_existing=false

if grep -q " ${DATA_DIR} " /proc/mounts 2>/dev/null; then
  data_mounted=true
fi
if $data_mounted && find "$DATA_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .; then
  data_existing=true
fi

usage_arch() {
  local arch
  arch=$(uname -m 2>/dev/null || printf 'unknown')
  case "$arch" in
    x86_64|amd64) printf 'amd64' ;;
    aarch64|arm64) printf 'arm64' ;;
    *) printf 'other' ;;
  esac
}

write_usage_state() {
  local state_file version tmp_file
  state_file=$1
  version=$2
  mkdir -p "$USAGE_STATE_DIR"
  tmp_file=$(mktemp "$USAGE_STATE_DIR/.usage.XXXXXX")
  printf '%s\n' "$version" > "$tmp_file"
  chmod 0644 "$tmp_file" 2>/dev/null || true
  mv "$tmp_file" "$state_file"
}

fetch_usage_asset() {
  local asset base_url
  asset=$1
  base_url=${USAGE_BASE_URL%/}
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --max-time 5 -o /dev/null "$base_url/$asset" >/dev/null 2>&1
  elif command -v wget >/dev/null 2>&1; then
    wget -q -T 5 -O /dev/null "$base_url/$asset" >/dev/null 2>&1
  else
    return 1
  fi
}

read_state_value() {
  [ -r "$1" ] || return 0
  tr -d '[:space:]' < "$1"
}

report_usage_counts() {
  local current_version arch state_file last_version action

  [ "${EMBED_DISABLE_USAGE_COUNTS:-0}" != "1" ] || return 0
  $data_mounted || return 0

  current_version="${IMAGE_FLAVOR:-unknown}-${IMAGE_VER:-unknown}"
  arch=$(usage_arch)

  state_file="$USAGE_STATE_DIR/embeddings.version"
  last_version=$(read_state_value "$state_file")
  action=

  if [ -z "$last_version" ]; then
    if $data_existing; then
      action=upgrade
    else
      action=deploy
    fi
  elif [ "$last_version" != "$current_version" ]; then
    action=upgrade
  fi

  if [ -n "$action" ]; then
    if fetch_usage_asset "cu-v1-embeddings-$action-cpu-$arch"; then
      write_usage_state "$state_file" "$current_version"
    fi
  fi
}

if [ -n "$EMBED_API_KEY" ]; then
  printf '%s' "$EMBED_API_KEY" > "$API_KEY_FILE"
  chmod 600 "$API_KEY_FILE"
elif [ -z "$EMBED_API_KEY_WAS_SET" ] && [ -f "$API_KEY_FILE" ]; then
  EMBED_API_KEY=$(cat "$API_KEY_FILE")
elif [ -z "$EMBED_API_KEY_WAS_SET" ] && $data_mounted && ! $data_existing; then
  EMBED_API_KEY="embed-$(head -c 32 /dev/urandom | od -A n -t x1 | tr -d ' \n' | head -c 48)"
  printf '%s' "$EMBED_API_KEY" > "$API_KEY_FILE"
  chmod 600 "$API_KEY_FILE"
  printf '%s\n' "true" > "$AUTO_API_KEY_MARKER"
  chmod 600 "$AUTO_API_KEY_MARKER"
fi

# Resolve reranker API key. When unset, it falls back to EMBED_API_KEY.
# When explicitly set empty, it remains empty as an intentional no-auth opt-out.
if [ -z "$RERANK_API_KEY_WAS_SET" ]; then
  RERANK_API_KEY="$EMBED_API_KEY"
fi

# In local-only mode, verify models are already cached before starting
if [ -n "$EMBED_LOCAL_ONLY" ]; then
  if [ "$embed_active" = 1 ]; then
    model_slug="models--$(printf '%s' "$EMBED_MODEL" | sed 's|/|--|g')"
    if [ ! -d "/var/lib/embeddings/${model_slug}" ]; then
      exiterr "EMBED_LOCAL_ONLY is set but model '${EMBED_MODEL}' is not found in /var/lib/embeddings. \
Pre-download it first: docker exec <container> embed_manage --pullmodel ${EMBED_MODEL}"
    fi
  fi
  if [ "$rerank_active" = 1 ]; then
    rerank_slug="models--$(printf '%s' "$RERANK_MODEL" | sed 's|/|--|g')"
    if [ ! -d "/var/lib/embeddings/${rerank_slug}" ]; then
      exiterr "EMBED_LOCAL_ONLY is set but reranker model '${RERANK_MODEL}' is not found in /var/lib/embeddings. \
Pre-download it first: docker exec <container> embed_manage --pullmodel ${RERANK_MODEL}"
    fi
  fi
fi

# Determine server address for display
public_ip=$(curl -s --max-time 10 http://ipv4.icanhazip.com 2>/dev/null || true)
check_ip "$public_ip" || public_ip=$(curl -s --max-time 10 http://ip1.dynupdate.no-ip.com 2>/dev/null || true)
if check_ip "$public_ip"; then
  server_addr="$public_ip"
else
  server_addr="<server ip>"
fi

# Export all config for manage.sh (read from persistent files when env is not present)
export EMBED_MODEL
export EMBED_PORT
export EMBED_API_KEY
export EMBED_HF_TOKEN
export EMBED_LOCAL_ONLY
export EMBED_ENABLED
export RERANK_ENABLED
export RERANK_MODEL
export RERANK_PORT
export RERANK_API_KEY
# Point TEI / HuggingFace Hub at the persistent Docker volume
export HF_HUB_CACHE=/var/lib/embeddings
export HUGGINGFACE_HUB_CACHE=/var/lib/embeddings

# Set offline flag for HuggingFace Hub libraries if local-only mode is enabled
if [ -n "$EMBED_LOCAL_ONLY" ]; then
  export HF_HUB_OFFLINE=1
fi

# Persist config values so embed_manage can read them without the env file
printf '%s' "$EMBED_PORT"  > /var/lib/embeddings/.port
printf '%s' "$EMBED_MODEL" > /var/lib/embeddings/.model
printf '%s' "$server_addr" > /var/lib/embeddings/.server_addr
printf '%s' "$embed_active" > /var/lib/embeddings/.embed_active
printf '%s' "$rerank_active" > /var/lib/embeddings/.rerank_active
printf '%s' "$RERANK_PORT"  > /var/lib/embeddings/.rerank_port
printf '%s' "$RERANK_MODEL" > /var/lib/embeddings/.rerank_model
if [ -n "$EMBED_API_KEY" ]; then
  printf '%s' "1" > /var/lib/embeddings/.embed_auth_enabled
else
  printf '%s' "0" > /var/lib/embeddings/.embed_auth_enabled
fi
if [ -n "$RERANK_API_KEY" ]; then
  printf '%s' "1" > /var/lib/embeddings/.rerank_auth_enabled
else
  printf '%s' "0" > /var/lib/embeddings/.rerank_auth_enabled
fi

echo
echo "Embeddings Docker - https://github.com/hwdsl2/docker-embeddings"

if ! grep -q " /var/lib/embeddings " /proc/mounts 2>/dev/null; then
  echo
  echo "Note: /var/lib/embeddings is not mounted. Model files will be lost on"
  echo "      container removal. Mount a Docker volume at /var/lib/embeddings"
  echo "      to persist the downloaded model across container restarts."
  if [ -z "$EMBED_API_KEY" ] && [ -z "$EMBED_API_KEY_WAS_SET" ]; then
    echo "      API key authentication was not auto-enabled because the"
    echo "      data directory is not persistent."
  fi
elif [ -z "$EMBED_API_KEY" ] && [ -z "$EMBED_API_KEY_WAS_SET" ] && $data_existing; then
  echo
  echo "Warning: Existing embeddings data was found but no API key is configured."
  echo "         Preserving no-auth behavior for backward compatibility."
  echo "         Set EMBED_API_KEY to enable authentication."
fi

echo
echo "Starting services..."
if [ "$embed_active" = 1 ]; then
  echo "  Embeddings: model=$EMBED_MODEL  port=$EMBED_PORT"
fi
if [ "$rerank_active" = 1 ]; then
  echo "  Reranker:   model=$RERANK_MODEL  port=$RERANK_PORT"
fi
if [ -n "$EMBED_LOCAL_ONLY" ]; then
  echo "  Mode: local-only (no HuggingFace downloads)"
fi

# Check if models are already cached
if [ -z "$EMBED_LOCAL_ONLY" ]; then
  if [ "$embed_active" = 1 ]; then
    model_slug="models--$(printf '%s' "$EMBED_MODEL" | sed 's|/|--|g')"
    if [ ! -d "/var/lib/embeddings/${model_slug}" ]; then
      echo
      echo "Note: Model '$EMBED_MODEL' not found in cache. It will be downloaded"
      echo "      from HuggingFace on first start. This may take several minutes."
    fi
  fi
  if [ "$rerank_active" = 1 ]; then
    rerank_slug="models--$(printf '%s' "$RERANK_MODEL" | sed 's|/|--|g')"
    if [ ! -d "/var/lib/embeddings/${rerank_slug}" ]; then
      echo
      echo "Note: Reranker model '$RERANK_MODEL' not found in cache. It will be"
      echo "      downloaded from HuggingFace on first start. This may take several minutes."
    fi
  fi
fi
echo

# Graceful shutdown — registered before starting the server so any SIGTERM
# received during the model-download startup phase is handled cleanly.
cleanup() {
  echo
  echo "Stopping services..."
  [ -n "$EMBED_PID" ] && kill "$EMBED_PID" 2>/dev/null
  [ -n "$RERANK_PID" ] && kill "$RERANK_PID" 2>/dev/null
  [ -n "$EMBED_PID" ] && wait "$EMBED_PID" 2>/dev/null
  [ -n "$RERANK_PID" ] && wait "$RERANK_PID" 2>/dev/null
  exit 0
}
trap cleanup INT TERM

EMBED_PID=""
RERANK_PID=""

# Start embeddings server
if [ "$embed_active" = 1 ]; then
  embed_cmd=(text-embeddings-router
    --model-id "$EMBED_MODEL"
    --port "$EMBED_PORT"
    --huggingface-hub-cache /var/lib/embeddings
  )
  [ -n "$EMBED_API_KEY" ]  && embed_cmd+=(--api-key "$EMBED_API_KEY")
  [ -n "$EMBED_HF_TOKEN" ] && embed_cmd+=(--hf-token "$EMBED_HF_TOKEN")

  "${embed_cmd[@]}" &
  EMBED_PID=$!
fi

# Start reranker server
if [ "$rerank_active" = 1 ]; then
  rerank_cmd=(text-embeddings-router
    --model-id "$RERANK_MODEL"
    --port "$RERANK_PORT"
    --huggingface-hub-cache /var/lib/embeddings
  )
  [ -n "$RERANK_API_KEY" ]  && rerank_cmd+=(--api-key "$RERANK_API_KEY")
  [ -n "$EMBED_HF_TOKEN" ] && rerank_cmd+=(--hf-token "$EMBED_HF_TOKEN")

  "${rerank_cmd[@]}" &
  RERANK_PID=$!
fi

# Wait for server(s) to become ready.
# Allow up to 300 seconds — first-run model download can take several minutes.
wait_for_server() {
  local pid="$1"
  local port="$2"
  local i=0
  while [ "$i" -lt 300 ]; do
    if ! kill -0 "$pid" 2>/dev/null; then
      return 1
    fi
    if curl -sf "http://127.0.0.1:${port}/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    i=$((i + 1))
  done
  return 1
}

if [ "$embed_active" = 1 ]; then
  if ! wait_for_server "$EMBED_PID" "$EMBED_PORT"; then
    if ! kill -0 "$EMBED_PID" 2>/dev/null; then
      echo "Error: Embeddings server failed to start. Check the container logs for details." >&2
    else
      echo "Error: Embeddings server did not become ready within 300 seconds." >&2
      kill "$EMBED_PID" 2>/dev/null
    fi
    [ -n "$RERANK_PID" ] && kill "$RERANK_PID" 2>/dev/null
    exit 1
  fi
fi

if [ "$rerank_active" = 1 ]; then
  if ! wait_for_server "$RERANK_PID" "$RERANK_PORT"; then
    if ! kill -0 "$RERANK_PID" 2>/dev/null; then
      echo "Error: Reranker server failed to start. Check the container logs for details." >&2
    else
      echo "Error: Reranker server did not become ready within 300 seconds." >&2
      kill "$RERANK_PID" 2>/dev/null
    fi
    [ -n "$EMBED_PID" ] && kill "$EMBED_PID" 2>/dev/null
    exit 1
  fi
fi

report_usage_counts

echo
echo "==========================================================="
if [ "$embed_active" = 1 ] && [ "$rerank_active" = 1 ]; then
  echo " Text embeddings & reranking server is ready"
elif [ "$rerank_active" = 1 ]; then
  echo " Reranking server is ready"
else
  echo " Text embeddings server is ready"
fi
echo "==========================================================="
if [ "$embed_active" = 1 ]; then
  echo " Embeddings:"
  echo "   Model:    $EMBED_MODEL"
  echo "   Endpoint: http://${server_addr}:${EMBED_PORT}"
fi
if [ "$rerank_active" = 1 ]; then
  if [ "$embed_active" = 1 ]; then
    echo " Reranker:"
  fi
  echo "   Model:    $RERANK_MODEL"
  echo "   Endpoint: http://${server_addr}:${RERANK_PORT}"
fi
echo "==========================================================="
echo

if [ "$embed_active" = 1 ]; then
  echo "Generate embeddings:"
  echo "  curl http://${server_addr}:${EMBED_PORT}/v1/embeddings \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"input\": \"Your text here\", \"model\": \"text-embedding-ada-002\"}'"
  echo
fi

if [ "$rerank_active" = 1 ]; then
  echo "Rerank documents:"
  echo "  curl http://${server_addr}:${RERANK_PORT}/rerank \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"query\": \"What is AI?\", \"texts\": [\"AI is...\", \"The weather is...\"], \"raw_scores\": false}'"
  echo
fi

if [ -n "$EMBED_API_KEY" ] && [ "$embed_active" = 1 ]; then
  echo "Embeddings API key authentication is enabled."
  echo "Include header:  -H \"Authorization: Bearer \$EMBED_API_KEY\""
  echo
fi
if [ -n "$RERANK_API_KEY" ] && [ "$rerank_active" = 1 ]; then
  echo "Reranker API key authentication is enabled."
  echo "Include header:  -H \"Authorization: Bearer \$RERANK_API_KEY\""
  echo
fi

if [ "$embed_active" = 1 ]; then
  echo "Embeddings API docs: http://${server_addr}:${EMBED_PORT}/docs"
fi
if [ "$rerank_active" = 1 ]; then
  echo "Reranker API docs:   http://${server_addr}:${RERANK_PORT}/docs"
fi
echo
echo "To set up HTTPS, see: Using a reverse proxy"
echo "  https://github.com/hwdsl2/docker-embeddings#using-a-reverse-proxy"
echo
echo "Setup complete."
echo

# Wait for either server process to exit
if [ "$embed_active" = 1 ] && [ "$rerank_active" = 1 ]; then
  # Wait for either process; if one dies, stop the other
  wait -n "$EMBED_PID" "$RERANK_PID" 2>/dev/null
  echo "Error: A server process exited unexpectedly." >&2
  cleanup
elif [ "$embed_active" = 1 ]; then
  wait "$EMBED_PID"
else
  wait "$RERANK_PID"
fi
