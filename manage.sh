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
EMBED_ACTIVE_FILE="${EMBED_DATA}/.embed_active"
RERANK_ACTIVE_FILE="${EMBED_DATA}/.rerank_active"
RERANK_PORT_FILE="${EMBED_DATA}/.rerank_port"
RERANK_MODEL_FILE="${EMBED_DATA}/.rerank_model"
EMBED_AUTH_ENABLED_FILE="${EMBED_DATA}/.embed_auth_enabled"
RERANK_AUTH_ENABLED_FILE="${EMBED_DATA}/.rerank_auth_enabled"
API_KEY_FILE="${EMBED_DATA}/.api_key"

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
  --showkey                            show the API key, if configured
  --getkey                             output the API key (machine-readable, no decoration)
  --listmodels                         list recommended embedding models with sizes
  --listrerankers                      list recommended reranker models with sizes
  --pullmodel <model>                  pre-download a model to the cache volume

  -h, --help                           show this help message and exit

The model is a HuggingFace model ID (e.g. BAAI/bge-small-en-v1.5).
Run '--listmodels' to see recommended embedding models.
Run '--listrerankers' to see recommended reranker (cross-encoder) models.

To switch the active model, set EMBED_MODEL=<id> and restart the container.
Use '--pullmodel' to pre-download a model before switching, avoiding a
delay on the next container start.

Examples:
  docker exec embeddings embed_manage --showinfo
  docker exec embeddings embed_manage --showkey
  docker exec embeddings embed_manage --getkey
  docker exec embeddings embed_manage --listmodels
  docker exec embeddings embed_manage --listrerankers
  docker exec embeddings embed_manage --pullmodel BAAI/bge-base-en-v1.5
  docker exec embeddings embed_manage --pullmodel BAAI/bge-reranker-v2-m3

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

  # Load reranker config
  if [ -f "$EMBED_ACTIVE_FILE" ]; then
    EMBED_ACTIVE=$(cat "$EMBED_ACTIVE_FILE")
  else
    EMBED_ACTIVE=1
  fi

  if [ -f "$RERANK_ACTIVE_FILE" ]; then
    RERANK_ACTIVE=$(cat "$RERANK_ACTIVE_FILE")
  else
    RERANK_ACTIVE=0
  fi

  if [ -f "$RERANK_PORT_FILE" ]; then
    RERANK_PORT=$(cat "$RERANK_PORT_FILE")
  else
    RERANK_PORT=8001
  fi

  if [ -f "$RERANK_MODEL_FILE" ]; then
    RERANK_MODEL=$(cat "$RERANK_MODEL_FILE")
  else
    RERANK_MODEL=BAAI/bge-reranker-v2-m3
  fi

  if [ -f "$EMBED_AUTH_ENABLED_FILE" ]; then
    EMBED_AUTH_ENABLED=$(cat "$EMBED_AUTH_ENABLED_FILE")
  fi

  if [ "$EMBED_AUTH_ENABLED" != 0 ] && [ -z "$EMBED_API_KEY" ] && [ -f "$API_KEY_FILE" ]; then
    EMBED_API_KEY=$(cat "$API_KEY_FILE")
  fi

  if [ -z "$EMBED_AUTH_ENABLED" ]; then
    if [ -n "$EMBED_API_KEY" ]; then
      EMBED_AUTH_ENABLED=1
    else
      EMBED_AUTH_ENABLED=0
    fi
  fi

  if [ -f "$RERANK_AUTH_ENABLED_FILE" ]; then
    RERANK_AUTH_ENABLED=$(cat "$RERANK_AUTH_ENABLED_FILE")
  elif [ -n "$EMBED_API_KEY" ]; then
    RERANK_AUTH_ENABLED=1
  else
    RERANK_AUTH_ENABLED=0
  fi
}

do_show_key() {
  if [ "$EMBED_AUTH_ENABLED" != 1 ] && [ "$RERANK_AUTH_ENABLED" != 1 ]; then
    exiterr "API key authentication is disabled for this container."
  fi

  if [ -z "$EMBED_API_KEY" ]; then
    if [ -f "$API_KEY_FILE" ]; then
      EMBED_API_KEY=$(cat "$API_KEY_FILE")
    else
      exiterr "API key not found. Authentication may be disabled for this container."
    fi
  fi

  echo
  echo "==========================================================="
  echo " Embeddings API key"
  echo "==========================================================="
  echo "${EMBED_API_KEY}"
  echo "==========================================================="
  echo
  echo "Use with: -H \"Authorization: Bearer ${EMBED_API_KEY}\""
  echo
}

do_get_key() {
  if [ "$EMBED_AUTH_ENABLED" != 1 ] && [ "$RERANK_AUTH_ENABLED" != 1 ]; then
    exit 1
  fi

  if [ -z "$EMBED_API_KEY" ]; then
    if [ -f "$API_KEY_FILE" ]; then
      EMBED_API_KEY=$(cat "$API_KEY_FILE")
    else
      exit 1
    fi
  fi

  printf '%s' "$EMBED_API_KEY"
}

check_server() {
  if [ "$EMBED_ACTIVE" = 1 ]; then
    if ! curl -sf "http://127.0.0.1:${EMBED_PORT}/health" >/dev/null 2>&1; then
      exiterr "Embeddings server is not responding on port ${EMBED_PORT}. Is the container fully started?"
    fi
  fi
  if [ "$RERANK_ACTIVE" = 1 ]; then
    if ! curl -sf "http://127.0.0.1:${RERANK_PORT}/health" >/dev/null 2>&1; then
      exiterr "Reranker server is not responding on port ${RERANK_PORT}. Is the container fully started?"
    fi
  fi
}

parse_args() {
  show_info=0
  show_key=0
  get_key=0
  list_models=0
  list_rerankers=0
  pull_model=0
  model_to_pull=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --showinfo)
        show_info=1
        shift
        ;;
      --showkey)
        show_key=1
        shift
        ;;
      --getkey)
        get_key=1
        shift
        ;;
      --listmodels)
        list_models=1
        shift
        ;;
      --listrerankers)
        list_rerankers=1
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
  action_count=$((show_info + show_key + get_key + list_models + list_rerankers + pull_model))

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
  if [ "$EMBED_ACTIVE" = 1 ] && [ "$RERANK_ACTIVE" = 1 ]; then
    echo " Text Embeddings & Reranking Server"
  elif [ "$RERANK_ACTIVE" = 1 ]; then
    echo " Reranking Server"
  else
    echo " Text Embeddings Server"
  fi
  echo "==========================================================="
  if [ "$EMBED_ACTIVE" = 1 ]; then
    echo " Embeddings:"
    echo "   Model:    $EMBED_MODEL"
    echo "   Endpoint: http://${SERVER_ADDR}:${EMBED_PORT}"
  fi
  if [ "$RERANK_ACTIVE" = 1 ]; then
    echo " Reranker:"
    echo "   Model:    $RERANK_MODEL"
    echo "   Endpoint: http://${SERVER_ADDR}:${RERANK_PORT}"
  fi
  echo "==========================================================="
  echo
  echo "API endpoints:"
  if [ "$EMBED_ACTIVE" = 1 ]; then
    echo "  POST http://${SERVER_ADDR}:${EMBED_PORT}/v1/embeddings"
    echo "  GET  http://${SERVER_ADDR}:${EMBED_PORT}/info"
    echo "  GET  http://${SERVER_ADDR}:${EMBED_PORT}/docs     (interactive docs)"
  fi
  if [ "$RERANK_ACTIVE" = 1 ]; then
    echo "  POST http://${SERVER_ADDR}:${RERANK_PORT}/rerank"
    echo "  GET  http://${SERVER_ADDR}:${RERANK_PORT}/info"
    echo "  GET  http://${SERVER_ADDR}:${RERANK_PORT}/docs     (interactive docs)"
  fi
  echo
  if [ "$EMBED_ACTIVE" = 1 ]; then
    echo "Example — generate embeddings:"
    echo "  curl http://${SERVER_ADDR}:${EMBED_PORT}/v1/embeddings \\"
    echo "    -H 'Content-Type: application/json' \\"
    if [ "$EMBED_AUTH_ENABLED" = 1 ]; then
      echo "    -H \"Authorization: Bearer <api-key>\" \\"
    fi
    echo "    -d '{\"input\": \"Your text here\", \"model\": \"text-embedding-ada-002\"}'"
    echo
  fi
  if [ "$RERANK_ACTIVE" = 1 ]; then
    echo "Example — rerank documents:"
    echo "  curl http://${SERVER_ADDR}:${RERANK_PORT}/rerank \\"
    echo "    -H 'Content-Type: application/json' \\"
    if [ "$RERANK_AUTH_ENABLED" = 1 ]; then
      echo "    -H \"Authorization: Bearer <api-key>\" \\"
    fi
    echo "    -d '{\"query\": \"What is AI?\", \"texts\": [\"AI is...\", \"The weather is...\"], \"raw_scores\": false}'"
    echo
  fi
  if [ "$EMBED_AUTH_ENABLED" = 1 ] || [ "$RERANK_AUTH_ENABLED" = 1 ]; then
    echo "Use '--showkey' to display the API key."
    echo
  fi
  echo "To change the active model:"
  echo "  1. Pre-download: docker exec <container> embed_manage --pullmodel <model>"
  echo "  2. Set EMBED_MODEL=<model> (or RERANK_MODEL=<model>) in your env file and restart."
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

do_list_rerankers() {
  cat <<'EOF'

Recommended reranker (cross-encoder) models for TEI:

  Model ID                               Disk      Notes
  --------                               ----      -----
  BAAI/bge-reranker-v2-m3               ~560 MB   Multilingual; strong accuracy — default
  BAAI/bge-reranker-base                ~440 MB   English; good balance
  BAAI/bge-reranker-large               ~1.3 GB   English; highest accuracy
  cross-encoder/ms-marco-MiniLM-L6-v2    ~90 MB   Very small; fast; English

Notes:
  - Reranker models are cross-encoders that score (query, document) pairs.
  - They are used to re-rank retrieved documents by relevance after initial
    retrieval via embeddings or keyword search.
  - Enable reranking by setting RERANK_ENABLED=true in your env file.
  - The reranker runs as a separate process on RERANK_PORT (default: 8001).
  - Any HuggingFace cross-encoder model compatible with TEI can be used.
    See: https://huggingface.co/models?pipeline_tag=text-classification&sort=downloads

Use '--pullmodel <model>' to pre-download a reranker model before enabling.

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
  echo "To activate this model, set EMBED_MODEL=${model_to_pull} (or RERANK_MODEL=${model_to_pull})"
  echo "in your env file (embed.env) and restart the container."
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

if [ "$show_key" = 1 ]; then
  do_show_key
  exit 0
fi

if [ "$get_key" = 1 ]; then
  do_get_key
  exit 0
fi

if [ "$list_models" = 1 ]; then
  do_list_models
  exit 0
fi

if [ "$list_rerankers" = 1 ]; then
  do_list_rerankers
  exit 0
fi

if [ "$pull_model" = 1 ]; then
  do_pull_model
  exit 0
fi
