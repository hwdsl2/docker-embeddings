#!/bin/bash
#
# https://github.com/hwdsl2/docker-embeddings
#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

export PATH="/opt/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

EMBED_DATA="/var/lib/embeddings"
PORT_FILE="${EMBED_DATA}/.port"
MODEL_FILE="${EMBED_DATA}/.model"
SERVER_ADDR_FILE="${EMBED_DATA}/.server_addr"

exiterr() { echo "Error: $1" >&2; exit 1; }

show_usage() {
  local exit_code="${2:-1}"
  if [ -n "$1" ]; then
    echo "Error: $1" >&2
  fi
  cat 1>&2 <<'EOF'

Embeddings Docker - Server Management
https://github.com/hwdsl2/docker-embeddings

Usage: docker exec <container> embed_manage [options]

Options:
  --showinfo                           show server info (model, endpoint, API docs)
  --listmodels                         list recommended embedding models with sizes
  --pullmodel <model>                  pre-download a model to the cache volume

  -h, --help                           show this help message and exit

The model is a HuggingFace model ID (e.g. BAAI/bge-small-en-v1.5).
Run '--listmodels' to see recommended models.

To switch the active model, set EMBED_MODEL=<id> and restart the container.
Use '--pullmodel' to pre-download a model before switching, avoiding a
delay on the next container start.

Examples:
  docker exec embeddings embed_manage --showinfo
  docker exec embeddings embed_manage --listmodels
  docker exec embeddings embed_manage --pullmodel BAAI/bge-base-en-v1.5
  docker exec embeddings embed_manage --pullmodel nomic-ai/nomic-embed-text-v1.5

EOF
  exit "$exit_code"
}

check_container() {
  if [ ! -f "/.dockerenv" ] && [ ! -f "/run/.containerenv" ] \
    && [ -z "$KUBERNETES_SERVICE_HOST" ] \
    && ! head -n 1 /proc/1/sched 2>/dev/null | grep -q '^run\.sh '; then
    exiterr "This script must be run inside a container (e.g. Docker, Podman)."
  fi
}

load_config() {
  if [ -z "$EMBED_PORT" ]; then
    if [ -f "$PORT_FILE" ]; then
      EMBED_PORT=$(cat "$PORT_FILE")
    else
      EMBED_PORT=8000
    fi
  fi

  if [ -z "$EMBED_MODEL" ]; then
    if [ -f "$MODEL_FILE" ]; then
      EMBED_MODEL=$(cat "$MODEL_FILE")
    else
      EMBED_MODEL=BAAI/bge-small-en-v1.5
    fi
  fi

  if [ -f "$SERVER_ADDR_FILE" ]; then
    SERVER_ADDR=$(cat "$SERVER_ADDR_FILE")
  else
    SERVER_ADDR="<server ip>"
  fi
}

check_server() {
  if ! curl -sf "http://127.0.0.1:${EMBED_PORT}/health" >/dev/null 2>&1; then
    exiterr "Embeddings server is not responding on port ${EMBED_PORT}. Is the container fully started?"
  fi
}

parse_args() {
  show_info=0
  list_models=0
  pull_model=0
  model_to_pull=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --showinfo)
        show_info=1
        shift
        ;;
      --listmodels)
        list_models=1
        shift
        ;;
      --pullmodel)
        pull_model=1
        model_to_pull="${2:-}"
        shift
        [ "$#" -gt 0 ] && shift
        ;;
      -h|--help)
        show_usage "" 0
        ;;
      *)
        show_usage "Unknown parameter: $1"
        ;;
    esac
  done
}

check_args() {
  local action_count
  action_count=$((show_info + list_models + pull_model))

  if [ "$action_count" -eq 0 ]; then
    show_usage
  fi
  if [ "$action_count" -gt 1 ]; then
    show_usage "Specify only one action at a time."
  fi

  if [ "$pull_model" = 1 ] && [ -z "$model_to_pull" ]; then
    exiterr "Missing model ID. Usage: --pullmodel <model>"
  fi
}

do_show_info() {
  echo
  echo "==========================================================="
  echo " Text Embeddings Server"
  echo "==========================================================="
  echo " Active model: $EMBED_MODEL"
  echo " Endpoint:     http://${SERVER_ADDR}:${EMBED_PORT}"
  echo "==========================================================="
  echo
  echo "API endpoints:"
  echo "  POST http://${SERVER_ADDR}:${EMBED_PORT}/v1/embeddings"
  echo "  GET  http://${SERVER_ADDR}:${EMBED_PORT}/info"
  echo "  GET  http://${SERVER_ADDR}:${EMBED_PORT}/docs     (interactive docs)"
  echo
  echo "Example — generate embeddings:"
  echo "  curl http://${SERVER_ADDR}:${EMBED_PORT}/v1/embeddings \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"input\": \"Your text here\", \"model\": \"text-embedding-ada-002\"}'"
  echo
  echo "To change the active model:"
  echo "  1. Pre-download: docker exec <container> embed_manage --pullmodel <model>"
  echo "  2. Set EMBED_MODEL=<model> in your env file and restart the container."
  echo
}

do_list_models() {
  cat <<'EOF'

Recommended embedding models (all TEI-compatible, CPU-only):

  Model ID                               Disk      Notes
  --------                               ----      -----
  BAAI/bge-small-en-v1.5                ~130 MB   Fastest; English — default
  BAAI/bge-base-en-v1.5                 ~440 MB   Good balance; English
  BAAI/bge-large-en-v1.5                ~1.3 GB   High accuracy; English
  BAAI/bge-m3                           ~570 MB   Multilingual; strong cross-lingual retrieval
  nomic-ai/nomic-embed-text-v1.5        ~550 MB   Strong multilingual; long context (8192 tokens)
  sentence-transformers/all-MiniLM-L6-v2 ~90 MB   Very small; fast; popular for semantic search

Notes:
  - All models are downloaded from HuggingFace on first start (or via --pullmodel)
    and cached in the /var/lib/embeddings Docker volume.
  - Models produce a fixed-length vector per input (embedding dimension varies by model).
  - Larger models generally produce higher-quality embeddings at the cost of more RAM
    and slower inference.
  - BAAI/bge-m3 and nomic-embed-text-v1.5 are recommended for non-English or
    multilingual workloads.
  - Any HuggingFace model supported by Hugging Face TEI can be used.
    See: https://huggingface.co/models?pipeline_tag=feature-extraction

Use '--pullmodel <model>' to pre-download a model before switching.

EOF
}

do_pull_model() {
  # Block download if EMBED_LOCAL_ONLY is set
  if [ -n "$EMBED_LOCAL_ONLY" ]; then
    exiterr "EMBED_LOCAL_ONLY is set — model downloads are disabled. Unset it to allow downloads."
  fi

  echo
  echo "Downloading model '${model_to_pull}' to /var/lib/embeddings..."
  echo "This may take several minutes depending on model size and network speed."
  echo

  export HF_HUB_CACHE=/var/lib/embeddings
  export HUGGINGFACE_HUB_CACHE=/var/lib/embeddings

  if [ -n "$EMBED_HF_TOKEN" ]; then
    export HUGGING_FACE_HUB_TOKEN="$EMBED_HF_TOKEN"
  fi

  _MODEL="$model_to_pull" python3 - << 'PYEOF'
import os, sys

model_id = os.environ["_MODEL"]
cache_dir = os.environ.get("HF_HUB_CACHE", "/var/lib/embeddings")
hf_token  = os.environ.get("HUGGING_FACE_HUB_TOKEN") or None

try:
    from huggingface_hub import snapshot_download
    print(f"  Downloading '{model_id}' ...")
    sys.stdout.flush()
    snapshot_download(
        repo_id=model_id,
        cache_dir=cache_dir,
        token=hf_token,
        # Skip weight formats not used by TEI (TensorFlow, Flax, rust_bert)
        ignore_patterns=["*.h5", "flax_model*", "tf_model*", "rust_model*.bin", "*.ot"],
    )
    print(f"  Model '{model_id}' downloaded successfully.")
    print(f"  Cache location: {cache_dir}")
except Exception as exc:
    print(f"Error: {exc}", file=sys.stderr)
    sys.exit(1)
PYEOF

  echo
  echo "To activate this model, set EMBED_MODEL=${model_to_pull} in your"
  echo "env file (embed.env) and restart the container."
  echo
}

check_container
load_config
parse_args "$@"
check_args

if [ "$show_info" = 1 ]; then
  check_server
  do_show_info
  exit 0
fi

if [ "$list_models" = 1 ]; then
  do_list_models
  exit 0
fi

if [ "$pull_model" = 1 ]; then
  do_pull_model
  exit 0
fi