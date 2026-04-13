[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# 文字向量化 API Docker 映像

[![建置狀態](https://github.com/hwdsl2/docker-embeddings/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-embeddings/actions/workflows/main.yml) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

使用 [Hugging Face Text Embeddings Inference (TEI)](https://github.com/huggingface/text-embeddings-inference) 在 Docker 容器中執行文字向量化伺服器。提供 OpenAI 相容的 `/v1/embeddings` API。簡單、私密、可自架。

- OpenAI 相容的 `POST /v1/embeddings` 端點 — 任何呼叫 OpenAI Embeddings API 的應用程式只需修改一行設定即可切換
- 由 [Hugging Face TEI](https://github.com/huggingface/text-embeddings-inference) 驅動 — 基於 Rust 的高效能向量化伺服器
- 支援主流向量化模型：`BAAI/bge-small-en-v1.5`、`BAAI/bge-m3`、`nomic-embed-text-v1.5` 等
- 透過輔助腳本 (`embed_manage`) 管理模型
- 文字資料留在您的伺服器上，不傳送給第三方
- 離線/隔離網路模式 — 使用預先快取的模型無需網際網路連線 (`EMBED_LOCAL_ONLY`)
- 可選 API 金鑰驗證 (`EMBED_API_KEY`)
- 透過 [GitHub Actions](https://github.com/hwdsl2/docker-embeddings/actions/workflows/main.yml) 自動建置並發布
- 透過 Docker 資料卷持久化模型快取
- 支援平台：`linux/amd64`

**另提供：**
- AI/音訊：[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh-Hant.md)、[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh-Hant.md)、[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh-Hant.md)
- VPN：[WireGuard](https://github.com/hwdsl2/docker-wireguard/blob/main/README-zh-Hant.md)、[OpenVPN](https://github.com/hwdsl2/docker-openvpn/blob/main/README-zh-Hant.md)、[IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server/blob/master/README-zh-Hant.md)、[Headscale](https://github.com/hwdsl2/docker-headscale/blob/main/README-zh-Hant.md)

**提示：** Whisper、Kokoro、Embeddings 和 LiteLLM 可以[搭配使用](#與其他-ai-服務搭配使用)，在您自己的伺服器上建立完整的私密 AI 系統。

## 快速開始

使用以下指令啟動文字向量化伺服器：

```bash
docker run \
    --name embeddings \
    --restart=always \
    -v embeddings-data:/var/lib/embeddings \
    -p 8000:8000 \
    -d hwdsl2/embeddings-server
```

**注：** 如需對外網路部署，**強烈建議**使用[反向代理](#使用反向代理)來新增 HTTPS。此時，還應將上述 `docker run` 指令中的 `-p 8000:8000` 替換為 `-p 127.0.0.1:8000:8000`，以防止從外部直接存取未加密的連接埠。

首次啟動時，預設模型 `BAAI/bge-small-en-v1.5`（約 130 MB）將自動下載並快取。查看日誌確認伺服器已就緒：

```bash
docker logs embeddings
```

看到 "Text embeddings server is ready" 後，產生您的第一個文字向量：

```bash
curl http://您的伺服器IP:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "The quick brown fox", "model": "text-embedding-ada-002"}'
```

**回應：**
```json
{"object":"list","data":[{"object":"embedding","embedding":[0.032,...,-0.017],"index":0}],"model":"BAAI/bge-small-en-v1.5","usage":{"prompt_tokens":5,"total_tokens":5}}
```

## 系統需求

- 已安裝 Docker 的 Linux 伺服器（本地或雲端）
- 支援的架構：`amd64`（x86_64）
- 最低記憶體：預設 `BAAI/bge-small-en-v1.5` 模型約需 250 MB 可用記憶體（請參閱[模型清單](#切換模型)）
- 首次啟動需要網際網路連線以下載模型（之後模型將快取在本地）。使用預先快取的模型並設定 `EMBED_LOCAL_ONLY=true` 時不需要網路連線。

如需對外網路部署，請參閱[使用反向代理](#使用反向代理)以啟用 HTTPS。

## 下載

從 [Docker Hub](https://hub.docker.com/r/hwdsl2/embeddings-server/) 取得可信賴的建置版本：

```bash
docker pull hwdsl2/embeddings-server
```

也可從 [Quay.io](https://quay.io/repository/hwdsl2/embeddings-server) 下載：

```bash
docker pull quay.io/hwdsl2/embeddings-server
docker image tag quay.io/hwdsl2/embeddings-server hwdsl2/embeddings-server
```

支援平台：`linux/amd64`。

## 環境變數

所有變數均為選填。若未設定，將自動套用安全的預設值。

此 Docker 映像使用以下變數，可在 `env` 檔案中宣告（參見[範例](embed.env.example)）：

| 變數 | 說明 | 預設值 |
|---|---|---|
| `EMBED_MODEL` | 用於向量化的 HuggingFace 模型 ID。請參閱[模型清單](#切換模型)。 | `BAAI/bge-small-en-v1.5` |
| `EMBED_PORT` | API 的 HTTP 連接埠（1–65535）。 | `8000` |
| `EMBED_API_KEY` | 選填的 Bearer 權杖。設定後所有請求須包含 `Authorization: Bearer <key>`。 | *（未設定）* |
| `EMBED_HF_TOKEN` | 用於存取私有或受限模型的 HuggingFace Hub 權杖。公開模型無需此項。 | *（未設定）* |
| `EMBED_LOCAL_ONLY` | 設為任意非空值（如 `true`）時，停用所有 HuggingFace 模型下載。適用於預先快取模型的離線或隔離網路部署。 | *（未設定）* |

**注：** 在 `env` 檔案中，值可用單引號括起，例如 `VAR='value'`。`=` 兩側不要有空格。若更改 `EMBED_PORT`，請相應更新 `docker run` 指令中的 `-p` 參數。

使用 `env` 檔案的範例：

```bash
cp embed.env.example embed.env
# 編輯 embed.env 設定您的參數，然後：
docker run \
    --name embeddings \
    --restart=always \
    -v embeddings-data:/var/lib/embeddings \
    -v ./embed.env:/embed.env:ro \
    -p 8000:8000 \
    -d hwdsl2/embeddings-server
```

`env` 檔案以掛載方式傳入容器，每次重新啟動時自動生效，無需重建容器。

也可透過 `--env-file` 傳入：

```bash
docker run \
    --name embeddings \
    --restart=always \
    -v embeddings-data:/var/lib/embeddings \
    -p 8000:8000 \
    --env-file=embed.env \
    -d hwdsl2/embeddings-server
```

## 使用 docker-compose

```bash
cp embed.env.example embed.env
# 依需求編輯 embed.env，然後：
docker compose up -d
docker logs embeddings
```

範例 `docker-compose.yml`（已包含在專案中）：

```yaml
services:
  embeddings:
    image: hwdsl2/embeddings-server
    container_name: embeddings
    restart: always
    ports:
      - "8000:8000/tcp"  # 若使用主機反向代理，改為 "127.0.0.1:8000:8000/tcp"
    volumes:
      - embeddings-data:/var/lib/embeddings
      - ./embed.env:/embed.env:ro

volumes:
  embeddings-data:
```

**注：** 如需對外網路部署，強烈建議使用[反向代理](#使用反向代理)啟用 HTTPS。此時請將 `docker-compose.yml` 中的 `"8000:8000/tcp"` 改為 `"127.0.0.1:8000:8000/tcp"`，以防止未加密連接埠被直接存取。

## API 參考

此 API 與 [OpenAI Embeddings 端點](https://platform.openai.com/docs/api-reference/embeddings)相容。任何已呼叫 `https://api.openai.com/v1/embeddings` 的應用程式，只需設定以下環境變數即可切換至自架服務：

```
OPENAI_BASE_URL=http://您的伺服器IP:8000
```

### 產生文字向量

```
POST /v1/embeddings
Content-Type: application/json
```

**參數：**

| 參數 | 類型 | 必填 | 說明 |
|---|---|---|---|
| `input` | 字串或陣列 | ✅ | 待向量化的文字。傳入字串表示單筆輸入，傳入字串陣列表示批次輸入。 |
| `model` | 字串 | ✅ | 傳入任意字串（如 `text-embedding-ada-002`）。該值僅用於 API 相容性，實際上一律使用 `EMBED_MODEL` 指定的模型。 |

**範例 — 單筆輸入：**

```bash
curl http://您的伺服器IP:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "The quick brown fox", "model": "text-embedding-ada-002"}'
```

**範例 — 批次輸入：**

```bash
curl http://您的伺服器IP:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": ["第一句話", "第二句話"], "model": "text-embedding-ada-002"}'
```

使用 API 金鑰驗證：

```bash
curl http://您的伺服器IP:8000/v1/embeddings \
    -H "Authorization: Bearer your_api_key" \
    -H "Content-Type: application/json" \
    -d '{"input": "您的文字內容", "model": "text-embedding-ada-002"}'
```

**回應：**

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

### 模型資訊

```
GET /info
```

返回目前使用的模型 ID、最大輸入長度和伺服器版本。

```bash
curl http://您的伺服器IP:8000/info
```

### 互動式 API 文件

可在以下網址存取互動式 Swagger UI：

```
http://您的伺服器IP:8000/docs
```

## 持久化資料

所有伺服器資料儲存在 Docker 資料卷（容器內的 `/var/lib/embeddings`）中：

```
/var/lib/embeddings/
├── models--BAAI--bge-small-en-v1.5/   # 已快取的模型檔案（從 HuggingFace 下載）
├── .port                # 目前連接埠（供 embed_manage 使用）
├── .model               # 目前模型 ID（供 embed_manage 使用）
└── .server_addr         # 已快取的伺服器 IP（供 embed_manage 使用）
```

請備份 Docker 資料卷以保留已下載的模型。模型大小從約 90 MB 到約 1.3 GB 不等，僅需下載一次；保留資料卷可避免重建容器時重新下載。

## 管理伺服器

在執行中的容器內使用 `embed_manage` 來檢視和管理伺服器。

**顯示伺服器資訊：**

```bash
docker exec embeddings embed_manage --showinfo
```

**列出推薦模型：**

```bash
docker exec embeddings embed_manage --listmodels
```

**預先下載模型：**

```bash
docker exec embeddings embed_manage --pullmodel BAAI/bge-base-en-v1.5
```

## 切換模型

要更換使用中的模型：

1. *（選填但建議）* 在伺服器執行中預先下載新模型：
   ```bash
   docker exec embeddings embed_manage --pullmodel BAAI/bge-base-en-v1.5
   ```

2. 在 `embed.env` 檔案中更新 `EMBED_MODEL`（或在 `docker run` 指令中加入 `-e EMBED_MODEL=BAAI/bge-base-en-v1.5`）。

3. 重新啟動容器：
   ```bash
   docker restart embeddings
   ```

**推薦模型：**

| 模型 | 磁碟空間 | 記憶體（約） | 說明 |
|---|---|---|---|
| `BAAI/bge-small-en-v1.5` | ~130 MB | ~250 MB | 最快；英語 — **預設** |
| `BAAI/bge-base-en-v1.5` | ~440 MB | ~700 MB | 良好平衡；英語 |
| `BAAI/bge-large-en-v1.5` | ~1.3 GB | ~2 GB | 高精度；英語 |
| `BAAI/bge-m3` | ~570 MB | ~1 GB | 多語言；跨語言檢索 |
| `nomic-ai/nomic-embed-text-v1.5` | ~550 MB | ~1 GB | 多語言；長上下文（8192 tokens） |
| `sentence-transformers/all-MiniLM-L6-v2` | ~90 MB | ~200 MB | 體積最小；速度快；適合語意搜尋 |

> **提示：** 對於非英語或多語言使用情境，推薦使用 `BAAI/bge-m3` 或 `nomic-ai/nomic-embed-text-v1.5`。對於英語 RAG 場景，`BAAI/bge-base-en-v1.5` 在精度與資源之間取得了良好平衡。

模型快取在 `/var/lib/embeddings` Docker 資料卷中，僅需下載一次。任何 TEI 支援的 HuggingFace 模型均可使用，參見 [TEI 支援的模型清單](https://huggingface.co/models?pipeline_tag=feature-extraction)。

## 使用反向代理

如需對外網路部署，可在向量化伺服器前置反向代理處理 HTTPS 終止。在本地或可信賴的網路中使用無需 HTTPS，但將 API 端點暴露在公開網路時建議啟用 HTTPS。

從反向代理存取向量化容器時使用以下地址之一：

- **`embeddings:8000`** — 若反向代理作為容器執行在與向量化伺服器**相同的 Docker 網路**中（例如定義在同一個 `docker-compose.yml` 中）。
- **`127.0.0.1:8000`** — 若反向代理執行在**主機上**且連接埠 `8000` 已發布（預設 `docker-compose.yml` 會發布該連接埠）。

**使用 [Caddy](https://caddyserver.com/docs/)（[Docker 映像](https://hub.docker.com/_/caddy)）的範例**（自動 Let's Encrypt TLS，反向代理在相同的 Docker 網路中）：

`Caddyfile`：
```
embeddings.example.com {
  reverse_proxy embeddings:8000
}
```

**使用 nginx 的範例**（反向代理執行在主機上）：

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

若伺服器對外網路開放，請在 `env` 檔案中設定 `EMBED_API_KEY`。

## 更新 Docker 映像

如需更新 Docker 映像和容器，首先[下載](#下載)最新版本：

```bash
docker pull hwdsl2/embeddings-server
```

若映像已是最新版本，您將看到：

```
Status: Image is up to date for hwdsl2/embeddings-server:latest
```

否則將下載最新版本。刪除並重新建立容器：

```bash
docker rm -f embeddings
# 然後使用相同的資料卷和連接埠重新執行快速開始中的 docker run 指令。
```

您下載的模型將保留在 `embeddings-data` 資料卷中。

## 與其他 AI 服務搭配使用

[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh-Hant.md)、[Embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-zh-Hant.md)、[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh-Hant.md) 和 [Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh-Hant.md) 映像可以組合使用，在您自己的伺服器上建立完整的私密 AI 系統——從語意文件搜尋和檢索增強生成（RAG）到完整的語音輸入/輸出。Whisper、Kokoro 和 Embeddings 完全在本地端執行。當 LiteLLM 僅使用本地端模型（例如 Ollama）時，資料不會傳送給第三方。如果您將 LiteLLM 設定為使用外部提供商（例如 OpenAI、Anthropic），您的資料將被傳送至這些提供商處理。

```mermaid
graph LR
    D["📄 文件"] -->|向量化| E["Embeddings<br/>(文字轉向量)"]
    E -->|儲存| VDB["向量資料庫<br/>(Qdrant, Chroma)"]
    A["🎤 語音輸入"] -->|轉錄| W["Whisper<br/>(語音轉文字)"]
    W -->|查詢| E
    VDB -->|上下文| L["LiteLLM<br/>(AI 閘道)"]
    W -->|文字| L
    L -->|回應| T["Kokoro TTS<br/>(文字轉語音)"]
    T --> B["🔊 語音輸出"]
```

| 服務 | 功能 | 預設連接埠 |
|---|---|---|
| **[Embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-zh-Hant.md)** | 將文字轉換為向量，用於語意搜尋和 RAG | `8000` |
| **[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh-Hant.md)** | 將語音音訊轉錄為文字 | `9000` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh-Hant.md)** | AI 閘道——將請求路由至 OpenAI、Anthropic、Ollama 及 100+ 其他提供商 | `4000` |
| **[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh-Hant.md)** | 將文字轉換為自然語音 | `8880` |

### RAG 檢索增強生成範例

對文件進行向量化以實現語意檢索，並將檢索到的上下文傳送給大型語言模型進行問答：

```bash
# 步驟 1：對文件片段進行向量化並存入向量資料庫
curl -s http://localhost:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "Docker simplifies deployment by packaging apps in containers.", "model": "text-embedding-ada-002"}' \
    | jq '.data[0].embedding'
# → 將返回的向量連同原文一起存入 Qdrant、Chroma、pgvector 等向量資料庫。

# 步驟 2：查詢時，對問題進行向量化並從向量資料庫檢索最相關的文件片段，
#          然後將問題和檢索到的上下文傳送給 LiteLLM 以取得 LLM 回應。
curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer <your-litellm-key>" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "gpt-4o",
      "messages": [
        {"role": "system", "content": "請僅根據所提供的上下文進行回答。"},
        {"role": "user", "content": "Docker 的作用是什麼？\n\n上下文：Docker 通過將應用打包為容器來簡化部署流程。"}
      ]
    }' \
    | jq -r '.choices[0].message.content'
```

### 語音對話範例

將語音問題轉錄為文字，從大型語言模型取得回答，並轉換為語音輸出：

```bash
# 步驟 1：將語音音訊轉錄為文字（Whisper）
TEXT=$(curl -s http://localhost:9000/v1/audio/transcriptions \
    -F file=@question.mp3 -F model=whisper-1 | jq -r .text)

# 步驟 2：將文字傳送給大型語言模型並取得回應（LiteLLM）
RESPONSE=$(curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer <your-litellm-key>" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"gpt-4o\",\"messages\":[{\"role\":\"user\",\"content\":\"$TEXT\"}]}" \
    | jq -r '.choices[0].message.content')

# 步驟 3：將回應轉換為語音（Kokoro TTS）
curl -s http://localhost:8880/v1/audio/speech \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"tts-1\",\"input\":\"$RESPONSE\",\"voice\":\"af_heart\"}" \
    --output response.mp3
```

## 技術細節

- 基礎映像：`ghcr.io/huggingface/text-embeddings-inference:cpu-latest`（Debian）
- 向量化引擎：[Hugging Face TEI](https://github.com/huggingface/text-embeddings-inference)（基於 Rust，高效能）
- API：OpenAI 相容的 `/v1/embeddings` 端點（由 TEI 直接提供）
- 資料目錄：`/var/lib/embeddings`（Docker 資料卷）
- 模型儲存：HuggingFace Hub 格式，儲存在資料卷中——下載一次，重新啟動後繼續使用
- 模型管理：Python（`huggingface_hub`）透過 `embed_manage --pullmodel` 預先下載

## 授權條款

**注：** 預建映像中包含的軟體元件（如 Hugging Face TEI 及其相依項目）均受各自版權持有者所選授權條款約束。使用預建映像時，使用者有責任確保其使用方式符合映像內所有軟體的相關授權條款要求。

版權所有 (C) 2026 Lin Song   
本作品採用 [MIT 授權條款](https://opensource.org/licenses/MIT)授權。

**Hugging Face Text Embeddings Inference (TEI)** 版權歸 Hugging Face, Inc. 所有，依據 [Apache 授權條款 2.0](https://github.com/huggingface/text-embeddings-inference/blob/main/LICENSE) 分發。

本專案是 Hugging Face TEI 的獨立 Docker 封裝，與 Hugging Face, Inc. 無關聯，未獲其背書或贊助。