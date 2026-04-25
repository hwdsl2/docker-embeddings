[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Text Embeddings API on Docker

[![Build Status](https://github.com/hwdsl2/docker-embeddings/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-embeddings/actions/workflows/main.yml) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

Docker image to run a self-hosted text embeddings server, powered by [Hugging Face Text Embeddings Inference (TEI)](https://github.com/huggingface/text-embeddings-inference). Provides an OpenAI-compatible `/v1/embeddings` API. Designed to be simple, private, and self-hosted.

**Features:**

- OpenAI-compatible `POST /v1/embeddings` endpoint — any app using the OpenAI embeddings API switches with a one-line change
- Powered by [Hugging Face TEI](https://github.com/huggingface/text-embeddings-inference) — a high-performance Rust-based embeddings server
- Supports popular embedding models: `BAAI/bge-small-en-v1.5`, `BAAI/bge-m3`, `nomic-embed-text-v1.5` and more
- Model management via a helper script (`embed_manage`)
- Text data stays on your server — no data sent to third parties
- Offline/air-gapped mode — run without internet access using pre-cached models (`EMBED_LOCAL_ONLY`)
- Automatically built and published via [GitHub Actions](https://github.com/hwdsl2/docker-embeddings/actions/workflows/main.yml)
- Persistent model cache via a Docker volume
- Supported platform: `linux/amd64`

**Also available:**

- AI/Audio: [Whisper (STT)](https://github.com/hwdsl2/docker-whisper), [Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro), [LiteLLM](https://github.com/hwdsl2/docker-litellm)
- VPN: [WireGuard](https://github.com/hwdsl2/docker-wireguard), [OpenVPN](https://github.com/hwdsl2/docker-openvpn), [IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server), [Headscale](https://github.com/hwdsl2/docker-headscale)

**Tip:** Whisper, Kokoro, Embeddings, and LiteLLM can be [used together](#using-with-other-ai-services) to build a complete, private AI stack on your own server.

## Quick start

Use this command to set up a text embeddings server:

```bash
docker run \
    --name embeddings \
    --restart=always \
    -v embeddings-data:/var/lib/embeddings \
    -p 8000:8000 \
    -d hwdsl2/embeddings-server
```

**Note:** For internet-facing deployments, using a [reverse proxy](#using-a-reverse-proxy) to add HTTPS is **strongly recommended**. In that case, also replace `-p 8000:8000` with `-p 127.0.0.1:8000:8000` in the `docker run` command above, to prevent direct access to the unencrypted port. Set `EMBED_API_KEY` in your `env` file when the server is accessible from the public internet.

The default model `BAAI/bge-small-en-v1.5` (~130 MB) is downloaded and cached on first start. Check the logs to confirm the server is ready:

```bash
docker logs embeddings
```

Once you see "Text embeddings server is ready", generate your first embeddings:

```bash
curl http://your_server_ip:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "The quick brown fox", "model": "text-embedding-ada-002"}'
```

**Response:**
```json
{"object":"list","data":[{"object":"embedding","embedding":[0.032,...,-0.017],"index":0}],"model":"BAAI/bge-small-en-v1.5","usage":{"prompt_tokens":5,"total_tokens":5}}
```

## Requirements

- A Linux server (local or cloud) with Docker installed
- Supported architecture: `amd64` (x86_64)
- Minimum RAM: ~250 MB free for the default `BAAI/bge-small-en-v1.5` model (see [model table](#switching-the-model))
- Internet access for the initial model download (the model is cached locally afterwards). Not required if using `EMBED_LOCAL_ONLY=true` with pre-cached models.

For internet-facing deployments, see [Using a reverse proxy](#using-a-reverse-proxy) to add HTTPS.

## Download

Get the trusted build from the [Docker Hub registry](https://hub.docker.com/r/hwdsl2/embeddings-server/):

```bash
docker pull hwdsl2/embeddings-server
```

Alternatively, you may download from [Quay.io](https://quay.io/repository/hwdsl2/embeddings-server):

```bash
docker pull quay.io/hwdsl2/embeddings-server
docker image tag quay.io/hwdsl2/embeddings-server hwdsl2/embeddings-server
```

Supported platform: `linux/amd64`.

## Environment variables

All variables are optional. If not set, secure defaults are used automatically.

This Docker image uses the following variables, that can be declared in an `env` file (see [example](embed.env.example)):

| Variable | Description | Default |
|---|---|---|
| `EMBED_MODEL` | HuggingFace model ID to use for embeddings. See [model table](#switching-the-model) for options. | `BAAI/bge-small-en-v1.5` |
| `EMBED_PORT` | HTTP port for the API (1–65535). | `8000` |
| `EMBED_API_KEY` | Optional Bearer token. If set, all API requests must include `Authorization: Bearer <key>`. | *(not set)* |
| `EMBED_HF_TOKEN` | HuggingFace Hub token for accessing private or gated models. Not required for public models. | *(not set)* |
| `EMBED_LOCAL_ONLY` | When set to any non-empty value (e.g. `true`), disables all HuggingFace model downloads. For offline or air-gapped deployments with pre-cached models. | *(not set)* |

**Note:** In your `env` file, you may enclose values in single quotes, e.g. `VAR='value'`. Do not add spaces around `=`. If you change `EMBED_PORT`, update the `-p` flag in the `docker run` command accordingly.

Example using an `env` file:

```bash
cp embed.env.example embed.env
# Edit embed.env with your settings, then:
docker run \
    --name embeddings \
    --restart=always \
    -v embeddings-data:/var/lib/embeddings \
    -v ./embed.env:/embed.env:ro \
    -p 8000:8000 \
    -d hwdsl2/embeddings-server
```

The env file is bind-mounted into the container, so changes are picked up on every restart without recreating the container.

<details>
<summary>Alternatively, pass it with <code>--env-file</code></summary>

```bash
docker run \
    --name embeddings \
    --restart=always \
    -v embeddings-data:/var/lib/embeddings \
    -p 8000:8000 \
    --env-file=embed.env \
    -d hwdsl2/embeddings-server
```

</details>

## Using docker-compose

```bash
cp embed.env.example embed.env
# Edit embed.env as needed, then:
docker compose up -d
docker logs embeddings
```

Example `docker-compose.yml` (already included):

```yaml
services:
  embeddings:
    image: hwdsl2/embeddings-server
    container_name: embeddings
    restart: always
    ports:
      - "8000:8000/tcp"  # For a host-based reverse proxy, change to "127.0.0.1:8000:8000/tcp"
    volumes:
      - embeddings-data:/var/lib/embeddings
      - ./embed.env:/embed.env:ro

volumes:
  embeddings-data:
```

**Note:** For internet-facing deployments, using a [reverse proxy](#using-a-reverse-proxy) to add HTTPS is **strongly recommended**. In that case, also change `"8000:8000/tcp"` to `"127.0.0.1:8000:8000/tcp"` in `docker-compose.yml`, to prevent direct access to the unencrypted port. Set `EMBED_API_KEY` in your `env` file when the server is accessible from the public internet.

## API reference

The API is compatible with [OpenAI's embeddings endpoint](https://platform.openai.com/docs/api-reference/embeddings). Any application already calling `https://api.openai.com/v1/embeddings` can switch to self-hosted by setting:

```
OPENAI_BASE_URL=http://your_server_ip:8000
```

### Generate embeddings

```
POST /v1/embeddings
Content-Type: application/json
```

**Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `input` | string or array | ✅ | Text to embed. Pass a string for a single input or an array of strings for batch embedding. |
| `model` | string | ✅ | Pass any string (e.g. `text-embedding-ada-002`). The value is accepted for API compatibility; the active model set by `EMBED_MODEL` is always used. |

**Example — single input:**

```bash
curl http://your_server_ip:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "The quick brown fox", "model": "text-embedding-ada-002"}'
```

**Example — batch input:**

```bash
curl http://your_server_ip:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": ["First sentence", "Second sentence"], "model": "text-embedding-ada-002"}'
```

With API key authentication:

```bash
curl http://your_server_ip:8000/v1/embeddings \
    -H "Authorization: Bearer your_api_key" \
    -H "Content-Type: application/json" \
    -d '{"input": "Your text here", "model": "text-embedding-ada-002"}'
```

**Response:**

```json
{
  "object": "list",
  "data": [
    {
      "object": "embedding",
      "embedding": [0.032, -0.018, ...],
      "index": 0
    }
  ],
  "model": "BAAI/bge-small-en-v1.5",
  "usage": { "prompt_tokens": 5, "total_tokens": 5 }
}
```

### Model info

```
GET /info
```

Returns the active model ID, maximum input length, and server version.

```bash
curl http://your_server_ip:8000/info
```

### Interactive API docs

An interactive Swagger UI is available at:

```
http://your_server_ip:8000/docs
```

## Persistent data

All server data is stored in the Docker volume (`/var/lib/embeddings` inside the container):

```
/var/lib/embeddings/
├── models--BAAI--bge-small-en-v1.5/   # Cached model files (downloaded from HuggingFace)
├── .port                # Active port (used by embed_manage)
├── .model               # Active model ID (used by embed_manage)
└── .server_addr         # Cached server IP (used by embed_manage)
```

Back up the Docker volume to preserve downloaded models. Models range from ~90 MB to ~1.3 GB and are only downloaded once; preserving the volume avoids re-downloading on container recreation.

## Managing the server

Use `embed_manage` inside the running container to inspect and manage the server.

**Show server info:**

```bash
docker exec embeddings embed_manage --showinfo
```

**List recommended models:**

```bash
docker exec embeddings embed_manage --listmodels
```

**Pre-download a model:**

```bash
docker exec embeddings embed_manage --pullmodel BAAI/bge-base-en-v1.5
```

## Switching the model

To change the active model:

1. *(Optional but recommended)* Pre-download the new model while the server is running:
   ```bash
   docker exec embeddings embed_manage --pullmodel BAAI/bge-base-en-v1.5
   ```

2. Update `EMBED_MODEL` in your `embed.env` file (or add `-e EMBED_MODEL=BAAI/bge-base-en-v1.5` to your `docker run` command).

3. Restart the container:
   ```bash
   docker restart embeddings
   ```

**Recommended models:**

| Model | Disk | RAM (approx) | Notes |
|---|---|---|---|
| `BAAI/bge-small-en-v1.5` | ~130 MB | ~250 MB | Fastest; English — **default** |
| `BAAI/bge-base-en-v1.5` | ~440 MB | ~700 MB | Good balance; English |
| `BAAI/bge-large-en-v1.5` | ~1.3 GB | ~2 GB | High accuracy; English |
| `BAAI/bge-m3` | ~570 MB | ~1 GB | Multilingual; cross-lingual retrieval |
| `nomic-ai/nomic-embed-text-v1.5` | ~550 MB | ~1 GB | Multilingual; long context (8192 tokens) |
| `sentence-transformers/all-MiniLM-L6-v2` | ~90 MB | ~200 MB | Very small; fast; popular for semantic search |

> **Tip:** `BAAI/bge-m3` and `nomic-ai/nomic-embed-text-v1.5` are recommended for non-English or multilingual workloads. For English RAG pipelines, `BAAI/bge-base-en-v1.5` offers a good accuracy-to-resource balance.

Models are cached in the `/var/lib/embeddings` Docker volume and only downloaded once. Any HuggingFace model supported by TEI can be used — see the [TEI supported models list](https://huggingface.co/models?pipeline_tag=feature-extraction).

## Using a reverse proxy

For internet-facing deployments, place a reverse proxy in front of the embeddings server to handle HTTPS termination. The server works without HTTPS on a local or trusted network, but HTTPS is recommended when the API endpoint is exposed to the internet.

Use one of the following addresses to reach the embeddings container from your reverse proxy:

- **`embeddings:8000`** — if your reverse proxy runs as a container in the **same Docker network** as the embeddings server (e.g. defined in the same `docker-compose.yml`).
- **`127.0.0.1:8000`** — if your reverse proxy runs **on the host** and port `8000` is published (the default `docker-compose.yml` publishes it).

**Example with [Caddy](https://caddyserver.com/docs/) ([Docker image](https://hub.docker.com/_/caddy))** (automatic TLS via Let's Encrypt, reverse proxy in the same Docker network):

`Caddyfile`:
```
embeddings.example.com {
  reverse_proxy embeddings:8000
}
```

**Example with nginx** (reverse proxy on the host):

```nginx
server {
    listen 443 ssl;
    server_name embeddings.example.com;

    ssl_certificate     /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass         http://127.0.0.1:8000;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
    }
}
```

Set `EMBED_API_KEY` in your `env` file when the server is accessible from the public internet.

## Update Docker image

To update the Docker image and container, first [download](#download) the latest version:

```bash
docker pull hwdsl2/embeddings-server
```

If the Docker image is already up to date, you should see:

```
Status: Image is up to date for hwdsl2/embeddings-server:latest
```

Otherwise, it will download the latest version. Remove and re-create the container:

```bash
docker rm -f embeddings
# Then re-run the docker run command from Quick start with the same volume and port.
```

Your downloaded models are preserved in the `embeddings-data` volume.

## Using with other AI services

The [Whisper (STT)](https://github.com/hwdsl2/docker-whisper), [Embeddings](https://github.com/hwdsl2/docker-embeddings), [LiteLLM](https://github.com/hwdsl2/docker-litellm), and [Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro) images can be combined to build a complete, private AI stack on your own server — from semantic document search and RAG to full voice I/O. Whisper, Kokoro, and Embeddings run fully locally. When using LiteLLM with local models only (e.g., Ollama), no data is sent to third parties. If you configure LiteLLM with external providers (e.g., OpenAI, Anthropic), your data will be sent to those providers.

```mermaid
graph LR
    D["📄 Documents"] -->|embed| E["Embeddings<br/>(text → vectors)"]
    E -->|store| VDB["Vector DB<br/>(Qdrant, Chroma)"]
    A["🎤 Audio input"] -->|transcribe| W["Whisper<br/>(speech-to-text)"]
    W -->|query| E
    VDB -->|context| L["LiteLLM<br/>(AI gateway)"]
    W -->|text| L
    L -->|response| T["Kokoro TTS<br/>(text-to-speech)"]
    T --> B["🔊 Audio output"]
```

| Service | Role | Default port |
|---|---|---|
| **[Embeddings](https://github.com/hwdsl2/docker-embeddings)** | Converts text to vectors for semantic search and RAG | `8000` |
| **[Whisper (STT)](https://github.com/hwdsl2/docker-whisper)** | Transcribes spoken audio to text | `9000` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm)** | AI gateway — routes requests to OpenAI, Anthropic, Ollama, and 100+ other providers | `4000` |
| **[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro)** | Converts text to natural-sounding speech | `8880` |

<details>
<summary><strong>RAG pipeline example</strong></summary>

Embed documents for semantic search, then retrieve context and answer questions with an LLM:

```bash
# Step 1: Embed a document chunk and store the vector in your vector DB
curl -s http://localhost:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "Docker simplifies deployment by packaging apps in containers.", "model": "text-embedding-ada-002"}' \
    | jq '.data[0].embedding'
# → Store the returned vector alongside the source text in Qdrant, Chroma, pgvector, etc.

# Step 2: At query time, embed the question, retrieve the top matching chunks from
#          the vector DB, then send the question and retrieved context to LiteLLM.
curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer <your-litellm-key>" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "gpt-4o",
      "messages": [
        {"role": "system", "content": "Answer using only the provided context."},
        {"role": "user", "content": "What does Docker do?\n\nContext: Docker simplifies deployment by packaging apps in containers."}
      ]
    }' \
    | jq -r '.choices[0].message.content'
```

</details>

<details>
<summary><strong>Voice pipeline example</strong></summary>

Transcribe a spoken question, get an LLM response, and convert it to speech:

```bash
# Step 1: Transcribe audio to text (Whisper)
TEXT=$(curl -s http://localhost:9000/v1/audio/transcriptions \
    -F file=@question.mp3 -F model=whisper-1 | jq -r .text)

# Step 2: Send text to an LLM and get a response (LiteLLM)
RESPONSE=$(curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer <your-litellm-key>" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"gpt-4o\",\"messages\":[{\"role\":\"user\",\"content\":\"$TEXT\"}]}" \
    | jq -r '.choices[0].message.content')

# Step 3: Convert the response to speech (Kokoro TTS)
curl -s http://localhost:8880/v1/audio/speech \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"tts-1\",\"input\":\"$RESPONSE\",\"voice\":\"af_heart\"}" \
    --output response.mp3
```

</details>

## Technical details

- Base image: `ghcr.io/huggingface/text-embeddings-inference:cpu-latest` (Debian)
- Embeddings engine: [Hugging Face TEI](https://github.com/huggingface/text-embeddings-inference) (Rust-based, high-performance)
- API: OpenAI-compatible `/v1/embeddings` endpoint (served directly by TEI)
- Data directory: `/var/lib/embeddings` (Docker volume)
- Model storage: HuggingFace Hub format inside the volume — downloaded once, reused on restarts
- Model management: Python (`huggingface_hub`) for pre-download via `embed_manage --pullmodel`

## License

**Note:** The software components inside the pre-built image (such as Hugging Face TEI and its dependencies) are under the respective licenses chosen by their respective copyright holders. As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.

Copyright (C) 2026 Lin Song   
This work is licensed under the [MIT License](https://opensource.org/licenses/MIT).

**Hugging Face Text Embeddings Inference (TEI)** is Copyright (C) Hugging Face, Inc., and is distributed under the [Apache License 2.0](https://github.com/huggingface/text-embeddings-inference/blob/main/LICENSE).

This project is an independent Docker setup for Hugging Face TEI and is not affiliated with, endorsed by, or sponsored by Hugging Face, Inc.