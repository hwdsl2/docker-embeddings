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

# Apply defaults
[ -z "$EMBED_MODEL" ] && EMBED_MODEL=BAAI/bge-small-en-v1.5
[ -z "$EMBED_PORT" ]  && EMBED_PORT=8000

# Validate port
if ! check_port "$EMBED_PORT"; then
  exiterr "EMBED_PORT must be an integer between 1 and 65535."
fi

mkdir -p /var/lib/embeddings

# In local-only mode, verify the model is already cached before starting
if [ -n "$EMBED_LOCAL_ONLY" ]; then
  model_slug="models--$(printf '%s' "$EMBED_MODEL" | sed 's|/|--|g')"
  if [ ! -d "/var/lib/embeddings/${model_slug}" ]; then
    exiterr "EMBED_LOCAL_ONLY is set but model '${EMBED_MODEL}' is not found in /var/lib/embeddings. \
Pre-download it first: docker exec <container> embed_manage --pullmodel ${EMBED_MODEL}"
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

echo
echo "Embeddings Docker - https://github.com/hwdsl2/docker-embeddings"

if ! grep -q " /var/lib/embeddings " /proc/mounts 2>/dev/null; then
  echo
  echo "Note: /var/lib/embeddings is not mounted. Model files will be lost on"
  echo "      container removal. Mount a Docker volume at /var/lib/embeddings"
  echo "      to persist the downloaded model across container restarts."
fi

echo
echo "Starting text embeddings server..."
echo "  Model: $EMBED_MODEL"
echo "  Port:  $EMBED_PORT"
if [ -n "$EMBED_LOCAL_ONLY" ]; then
  echo "  Mode:  local-only (no HuggingFace downloads)"
fi

# Check if model is already cached (HF Hub cache dir format: models--ORG--MODELNAME)
if [ -z "$EMBED_LOCAL_ONLY" ]; then
  model_slug="models--$(printf '%s' "$EMBED_MODEL" | sed 's|/|--|g')"
  if [ ! -d "/var/lib/embeddings/${model_slug}" ]; then
    echo
    echo "Note: Model '$EMBED_MODEL' not found in cache. It will be downloaded"
    echo "      from HuggingFace on first start. This may take several minutes."
  fi
fi
echo

# Graceful shutdown — registered before starting the server so any SIGTERM
# received during the model-download startup phase is handled cleanly.
cleanup() {
  echo
  echo "Stopping embeddings server..."
  kill "${EMBED_PID:-}" 2>/dev/null
  wait "${EMBED_PID:-}" 2>/dev/null
  exit 0
}
trap cleanup INT TERM

# Build the text-embeddings-router command as an array to handle
# special characters in API keys correctly.
tei_cmd=(text-embeddings-router
  --model-id "$EMBED_MODEL"
  --port "$EMBED_PORT"
  --huggingface-hub-cache /var/lib/embeddings
)

[ -n "$EMBED_API_KEY" ]  && tei_cmd+=(--api-key "$EMBED_API_KEY")
[ -n "$EMBED_HF_TOKEN" ] && tei_cmd+=(--hf-api-token "$EMBED_HF_TOKEN")

# Start the TEI server in the background
"${tei_cmd[@]}" &
EMBED_PID=$!

# Wait for the server to become ready.
# Allow up to 300 seconds — first-run model download can take several minutes
# on a slow connection even for the small default model (~130 MB).
wait_for_server() {
  local i=0
  while [ "$i" -lt 300 ]; do
    if ! kill -0 "$EMBED_PID" 2>/dev/null; then
      return 1
    fi
    if curl -sf "http://127.0.0.1:${EMBED_PORT}/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    i=$((i + 1))
  done
  return 1
}

if ! wait_for_server; then
  if ! kill -0 "$EMBED_PID" 2>/dev/null; then
    echo "Error: Embeddings server failed to start. Check the container logs for details." >&2
  else
    echo "Error: Embeddings server did not become ready within 300 seconds." >&2
    kill "$EMBED_PID" 2>/dev/null
  fi
  exit 1
fi

echo
echo "==========================================================="
echo " Text embeddings server is ready"
echo "==========================================================="
echo " Model:    $EMBED_MODEL"
echo " Endpoint: http://${server_addr}:${EMBED_PORT}"
echo "==========================================================="
echo
echo "Generate embeddings:"
echo "  curl http://${server_addr}:${EMBED_PORT}/v1/embeddings \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"input\": \"Your text here\", \"model\": \"text-embedding-ada-002\"}'"
echo
if [ -n "$EMBED_API_KEY" ]; then
  echo "API key authentication is enabled."
  echo "Include header:  -H \"Authorization: Bearer \$EMBED_API_KEY\""
  echo
fi
echo "Interactive API docs: http://${server_addr}:${EMBED_PORT}/docs"
echo
echo "To set up HTTPS, see: Using a reverse proxy"
echo "  https://github.com/hwdsl2/docker-embeddings#using-a-reverse-proxy"
echo
echo "Setup complete."
echo

# Wait for the server process to exit
wait "$EMBED_PID"