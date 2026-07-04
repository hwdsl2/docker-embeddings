[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# 文本向量化与重排序 API Docker 镜像

[![构建状态](https://github.com/hwdsl2/docker-embeddings/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-embeddings/actions/workflows/main.yml) &nbsp;[![Docker Pulls](https://raw.githubusercontent.com/hwdsl2/badges/main/img/docker-pulls-embeddings-server.svg)](https://hub.docker.com/r/hwdsl2/embeddings-server) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

[Self-Hosted AI Stack](https://github.com/hwdsl2/self-hosted-ai-stack/blob/main/README-zh.md) 的一部分 ─ 一条命令部署完整的自托管 AI 技术栈。

使用 [Hugging Face Text Embeddings Inference (TEI)](https://github.com/huggingface/text-embeddings-inference) 在 Docker 容器中运行文本向量化与重排序服务器。提供 OpenAI 兼容的 `/v1/embeddings` API 和 `/rerank` 接口。简单、私密、可自托管。

**功能特性：**

- OpenAI 兼容的 `POST /v1/embeddings` 接口 — 任何调用 OpenAI Embeddings API 的应用只需修改一行配置即可切换
- 由 [Hugging Face TEI](https://github.com/huggingface/text-embeddings-inference) 驱动 — 基于 Rust 的高性能向量化服务器
- 支持主流向量化模型：`BAAI/bge-small-en-v1.5`、`BAAI/bge-m3`、`nomic-embed-text-v1.5` 等
- 可选的重排序接口（`POST /rerank`）— 启用交叉编码器模型对检索文档重新评分，提升检索精度
- 通过辅助脚本 (`embed_manage`) 管理模型
- 文本数据留在您的服务器上，不发送给第三方
- 离线/隔离网络模式 — 使用预先缓存的模型无需互联网访问 (`EMBED_LOCAL_ONLY`)
- 通过 [GitHub Actions](https://github.com/hwdsl2/docker-embeddings/actions/workflows/main.yml) 自动构建和发布
- 通过 Docker 数据卷持久化模型缓存
- 支持平台：`linux/amd64`、`linux/arm64`

**另提供：**

- AI 套件：[Self-Hosted AI Stack](https://github.com/hwdsl2/self-hosted-ai-stack/blob/main/README-zh.md)
- 相关 AI 服务：[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh.md)、[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh.md)、[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md)、[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh.md)、[Docling](https://github.com/hwdsl2/docker-docling/blob/main/README-zh.md)、[MCP Gateway](https://github.com/hwdsl2/docker-mcp-gateway/blob/main/README-zh.md)

## 社区

- 📬 [订阅项目更新](https://selfhostedstack.beehiiv.com/subscribe?utm_campaign=ai-zh)（每月 1–2 封邮件）——获取免费的 AI 和 VPN 部署指南（PDF，英文）
- 💬 加入 [r/selfhostedstack](https://www.reddit.com/r/selfhostedstack/) 社区，参与讨论和项目展示
- ⭐ 如果你觉得本项目有用，请为仓库加星——这有助于让更多人发现它。

<details>
<summary>自托管 VPN 和网络项目</summary>

- [Setup IPsec VPN](https://github.com/hwdsl2/setup-ipsec-vpn/blob/master/README-zh.md)
- [Docker 上的 IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server/blob/master/README-zh.md)
- [WireGuard](https://github.com/hwdsl2/docker-wireguard/blob/main/README-zh.md)
- [OpenVPN](https://github.com/hwdsl2/docker-openvpn/blob/main/README-zh.md)
- [Headscale](https://github.com/hwdsl2/docker-headscale/blob/main/README-zh.md)

</details>

## 快速开始

使用以下命令启动文本向量化服务器：

```bash
docker run \
    --name embeddings \
    --restart=always \
    -v embeddings-data:/var/lib/embeddings \
    -p 8000:8000 \
    -d hwdsl2/embeddings-server
```

**注：** 如需面向互联网的部署，**强烈建议**使用[反向代理](#使用反向代理)来添加 HTTPS。此时，还应将上述 `docker run` 命令中的 `-p 8000:8000` 替换为 `-p 127.0.0.1:8000:8000`，以防止从外部直接访问未加密端口。

首次启动时，默认模型 `BAAI/bge-small-en-v1.5`（约 130 MB）将自动下载并缓存。查看日志确认服务器已就绪：

```bash
docker logs embeddings
```

看到 "Text embeddings server is ready" 后，生成您的第一个文本向量：

```bash
curl http://您的服务器IP:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "The quick brown fox", "model": "text-embedding-ada-002"}'
```

**响应：**
```json
{"object":"list","data":[{"object":"embedding","embedding":[0.032,...,-0.017],"index":0}],"model":"BAAI/bge-small-en-v1.5","usage":{"prompt_tokens":5,"total_tokens":5}}
```

## 系统要求

- 已安装 Docker 的 Linux 服务器（本地或云端）
- 支持的架构：`amd64`（x86_64）、`arm64`（aarch64，如 AWS Graviton、Apple Silicon 虚拟机）
- 最低内存：默认 `BAAI/bge-small-en-v1.5` 模型约需 250 MB 可用内存（请参阅[模型列表](#切换模型)）
- 首次启动需要访问互联网以下载模型（之后模型将缓存在本地）。使用预先缓存的模型并设置 `EMBED_LOCAL_ONLY=true` 时不需要网络访问。

如需面向公网部署，请参阅[使用反向代理](#使用反向代理)以启用 HTTPS。

## 下载

从 [Docker Hub](https://hub.docker.com/r/hwdsl2/embeddings-server/) 获取可信构建：

```bash
docker pull hwdsl2/embeddings-server
```

也可从 [Quay.io](https://quay.io/repository/hwdsl2/embeddings-server) 下载：

```bash
docker pull quay.io/hwdsl2/embeddings-server
docker image tag quay.io/hwdsl2/embeddings-server hwdsl2/embeddings-server
```

支持平台：`linux/amd64`、`linux/arm64`。

## 环境变量

所有变量均为可选。挂载 `/var/lib/embeddings` 数据卷的新安装会自动生成 Bearer 令牌。没有密钥的既有安装会保持开放以兼容旧行为。

此 Docker 镜像使用以下变量，可在 `env` 文件中声明（参见[示例](embed.env.example)）：

| 变量 | 说明 | 默认值 |
|---|---|---|
| `EMBED_MODEL` | 用于向量化的 HuggingFace 模型 ID。请参阅[模型列表](#切换模型)。 | `BAAI/bge-small-en-v1.5` |
| `EMBED_PORT` | API 的 HTTP 端口（1–65535）。 | `8000` |
| `EMBED_API_KEY` | 可选的 Bearer 令牌。新持久化安装会自动生成。设置后所有 API 请求须包含 `Authorization: Bearer <key>`。显式设置为空可禁用认证。 | 新持久化安装自动生成 |
| `EMBED_HF_TOKEN` | 用于访问私有或受限模型的 HuggingFace Hub 令牌。公开模型无需此项。 | *（未设置）* |
| `EMBED_LOCAL_ONLY` | 设为任意非空值（如 `true`）时，禁止所有 HuggingFace 模型下载。适用于预先缓存模型的离线或隔离网络部署。 | *（未设置）* |
| `EMBED_ENABLED` | 设为 `false` 可禁用向量化进程（用于仅重排序模式）。 | `true` |
| `RERANK_ENABLED` | 设为 `true` 可启用重排序服务器（在独立端口运行交叉编码器模型）。 | *（未设置）* |
| `RERANK_MODEL` | 用于重排序的 HuggingFace 交叉编码器模型 ID。请参阅[重排序模型](#重排序)。 | `BAAI/bge-reranker-v2-m3` |
| `RERANK_PORT` | 重排序 API 的 HTTP 端口。如向量化已禁用，则默认为 `8000`。 | `8001` |
| `RERANK_API_KEY` | 重排序的可选 Bearer 令牌。未设置时回退到 `EMBED_API_KEY`。显式设置为空可禁用重排序认证。 | *（回退到 `EMBED_API_KEY`）* |

**注：** 在 `env` 文件中，值可用单引号括起，例如 `VAR='value'`。`=` 两侧不要有空格。如更改 `EMBED_PORT`，请相应更新 `docker run` 命令中的 `-p` 参数。

使用 `env` 文件的示例：

```bash
cp embed.env.example embed.env
# 编辑 embed.env 配置您的设置，然后：
docker run \
    --name embeddings \
    --restart=always \
    -v embeddings-data:/var/lib/embeddings \
    -v ./embed.env:/embed.env:ro \
    -p 8000:8000 \
    -d hwdsl2/embeddings-server
```

`env` 文件以绑定挂载方式传入容器，每次重启时自动生效，无需重建容器。

<details>
<summary>也可通过 <code>--env-file</code> 传入</summary>

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

## 使用 docker-compose

```bash
cp embed.env.example embed.env
# 按需编辑 embed.env，然后：
docker compose up -d
docker logs embeddings
```

示例 `docker-compose.yml`（已包含在项目中）：

```yaml
services:
  embeddings:
    image: hwdsl2/embeddings-server
    container_name: embeddings
    restart: always
    ports:
      - "8000:8000/tcp"  # 如使用主机反向代理，改为 "127.0.0.1:8000:8000/tcp"
      # - "8001:8001/tcp"  # 重排序 API（如在 embed.env 中设置 RERANK_ENABLED=true 则取消注释）
    volumes:
      - embeddings-data:/var/lib/embeddings
      - ./embed.env:/embed.env:ro

volumes:
  embeddings-data:
    name: embeddings-data
```

**注：** 如需面向公网部署，强烈建议使用[反向代理](#使用反向代理)启用 HTTPS。此时请将 `docker-compose.yml` 中的 `"8000:8000/tcp"` 改为 `"127.0.0.1:8000:8000/tcp"`，以防止未加密端口被直接访问。

## API 参考

该 API 与 [OpenAI Embeddings 接口](https://platform.openai.com/docs/api-reference/embeddings)兼容。任何已调用 `https://api.openai.com/v1/embeddings` 的应用，只需设置以下环境变量即可切换到自托管服务：

`/v1/embeddings` 接口由 TEI 直接提供。支持的 OpenAI 请求字段取决于 TEI；`encoding_format`、`dimensions`、`user` 和 token 数组输入等字段依赖上游实现，本镜像未对其进行文档说明或测试。

```
OPENAI_BASE_URL=http://您的服务器IP:8000
```

### 生成文本向量

```
POST /v1/embeddings
Content-Type: application/json
```

**参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `input` | 字符串或数组 | ✅ | 待向量化的文本。传入字符串表示单条输入，传入字符串数组表示批量输入。 |
| `model` | 字符串 | ✅ | 传入任意字符串（如 `text-embedding-ada-002`）。该值仅用于 API 兼容性，实际始终使用 `EMBED_MODEL` 指定的模型。 |

**示例 — 单条输入：**

```bash
curl http://您的服务器IP:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "The quick brown fox", "model": "text-embedding-ada-002"}'
```

**示例 — 批量输入：**

```bash
curl http://您的服务器IP:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": ["第一句话", "第二句话"], "model": "text-embedding-ada-002"}'
```

使用 API 密钥认证：

```bash
curl http://您的服务器IP:8000/v1/embeddings \
    -H "Authorization: Bearer your_api_key" \
    -H "Content-Type: application/json" \
    -d '{"input": "您的文本内容", "model": "text-embedding-ada-002"}'
```

**响应：**

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

### 模型信息

```
GET /info
```

返回当前活跃模型 ID、最大输入长度和服务器版本。

```bash
curl http://您的服务器IP:8000/info
```

### 重排序文档

> 需要在 env 文件中设置 `RERANK_ENABLED=true`。重排序服务默认运行在端口 8001。

```
POST /rerank
Content-Type: application/json
```

**参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `query` | 字符串 | ✅ | 用于对文档进行排序的搜索查询。 |
| `texts` | 字符串数组 | ✅ | 待重排序的文档。 |
| `raw_scores` | 布尔值 | | 如为 `true`，返回原始交叉编码器分数而非归一化分数。默认：`false`。 |
| `truncate` | 布尔值 | | 如为 `true`，截断超出模型最大长度的输入。默认：`true`。 |

**示例：**

```bash
curl http://您的服务器IP:8001/rerank \
    -H "Content-Type: application/json" \
    -d '{
      "query": "什么是深度学习？",
      "texts": [
        "深度学习是机器学习的一个子集...",
        "今天天气晴朗，最高气温 25°C。",
        "神经网络的灵感来自人脑。"
      ],
      "raw_scores": false
    }'
```

**响应：**

```json
[
  {"index": 0, "score": 0.98},
  {"index": 2, "score": 0.72},
  {"index": 1, "score": 0.01}
]
```

结果按相关性分数降序排列（最高分在前）。可用于对向量相似性搜索返回的文档进行二次排序。

### 交互式 API 文档

可在以下地址访问交互式 Swagger UI：

```
http://您的服务器IP:8000/docs
```

如启用了重排序，重排序服务也有其独立的交互式文档：

```
http://您的服务器IP:8001/docs
```

## 持久化数据

所有服务器数据存储在 Docker 数据卷（容器内的 `/var/lib/embeddings`）中：

```
/var/lib/embeddings/
├── models--BAAI--bge-small-en-v1.5/   # 缓存的向量化模型文件
├── models--BAAI--bge-reranker-v2-m3/  # 缓存的重排序模型文件（如已启用）
├── .port                # 当前端口（供 embed_manage 使用）
├── .model               # 当前模型 ID（供 embed_manage 使用）
├── .rerank_model        # 当前重排序模型（供 embed_manage 使用）
├── .rerank_port         # 当前重排序端口（供 embed_manage 使用）
└── .server_addr         # 缓存的服务器 IP（供 embed_manage 使用）
```

请备份 Docker 数据卷以保留已下载的模型。模型大小从约 90 MB 到约 1.3 GB 不等，仅需下载一次；保留数据卷可避免在重建容器时重新下载。

## 管理服务器

在运行中的容器内使用 `embed_manage` 来查看和管理服务器。

**显示服务器信息：**

```bash
docker exec embeddings embed_manage --showinfo
```

**列出推荐模型：**

```bash
docker exec embeddings embed_manage --listmodels
```

**列出推荐重排序模型：**

```bash
docker exec embeddings embed_manage --listrerankers
```

**预先下载模型：**

```bash
docker exec embeddings embed_manage --pullmodel BAAI/bge-base-en-v1.5
docker exec embeddings embed_manage --pullmodel BAAI/bge-reranker-v2-m3
```

## 切换模型

要更换活跃模型：

1. *（可选但建议）* 在服务器运行时预先下载新模型：
   ```bash
   docker exec embeddings embed_manage --pullmodel BAAI/bge-base-en-v1.5
   ```

2. 在 `embed.env` 文件中更新 `EMBED_MODEL`（或在 `docker run` 命令中添加 `-e EMBED_MODEL=BAAI/bge-base-en-v1.5`）。

3. 重启容器：
   ```bash
   docker restart embeddings
   ```

**推荐模型：**

| 模型 | 磁盘占用 | 内存（约） | 说明 |
|---|---|---|---|
| `BAAI/bge-small-en-v1.5` | ~130 MB | ~250 MB | 最快；英语 — **默认** |
| `BAAI/bge-base-en-v1.5` | ~440 MB | ~700 MB | 良好平衡；英语 |
| `BAAI/bge-large-en-v1.5` | ~1.3 GB | ~2 GB | 高精度；英语 |
| `BAAI/bge-m3` | ~570 MB | ~1 GB | 多语言；跨语言检索 |
| `nomic-ai/nomic-embed-text-v1.5` | ~550 MB | ~1 GB | 多语言；长上下文（8192 词元） |
| `sentence-transformers/all-MiniLM-L6-v2` | ~90 MB | ~200 MB | 体积最小；速度快；适合语义搜索 |

> **提示：** 对于非英语或多语言使用场景，推荐使用 `BAAI/bge-m3` 或 `nomic-ai/nomic-embed-text-v1.5`。对于英语 RAG 场景，`BAAI/bge-base-en-v1.5` 在精度与资源之间取得了良好平衡。

模型缓存在 `/var/lib/embeddings` Docker 数据卷中，仅需下载一次。任何 TEI 支持的 HuggingFace 模型均可使用，参见 [TEI 支持的模型列表](https://huggingface.co/models?pipeline_tag=feature-extraction)。

## 重排序

重排序通过交叉编码器模型对文档重新评分，从而提升检索质量。在 env 文件中设置 `RERANK_ENABLED=true` 即可启用。

### 快速设置

1. 在 `embed.env` 中添加：
   ```bash
   RERANK_ENABLED=true
   ```

2. 暴露端口 8001（在 `docker run` 命令中添加 `-p 8001:8001`，或在 `docker-compose.yml` 中取消注释该端口）。

3. 重启容器：
   ```bash
   docker restart embeddings
   ```

重排序模型（`BAAI/bge-reranker-v2-m3`，约 560 MB）将在首次启动时下载。

### 运行模式

| 模式 | 配置 | 内存（约） |
|---|---|---|
| 仅向量化（默认） | `RERANK_ENABLED` 未设置 | ~250 MB (bge-small) |
| 向量化 + 重排序 | `RERANK_ENABLED=true` | ~850 MB (bge-small + bge-reranker-v2-m3) |
| 仅重排序 | `EMBED_ENABLED=false`, `RERANK_ENABLED=true` | ~600 MB (bge-reranker-v2-m3) |

在**仅重排序模式**下，重排序服务默认监听端口 8000（因为向量化进程已禁用），除非明确设置了 `RERANK_PORT`。

### 推荐重排序模型

| 模型 | 磁盘占用 | 内存（约） | 说明 |
|---|---|---|---|
| `BAAI/bge-reranker-v2-m3` | ~560 MB | ~600 MB | 多语言；精度高 — **默认** |
| `BAAI/bge-reranker-base` | ~440 MB | ~500 MB | 英语；良好平衡 |
| `BAAI/bge-reranker-large` | ~1.3 GB | ~1.5 GB | 英语；最高精度 |
| `cross-encoder/ms-marco-MiniLM-L6-v2` | ~90 MB | ~150 MB | 体积最小；速度快；英语 |

### 与 LiteLLM 配合使用

要将重排序服务与 [LiteLLM](https://github.com/hwdsl2/docker-litellm) 配合使用，请在 LiteLLM 配置中添加重排序模型：

```yaml
model_list:
  - model_name: rerank
    litellm_params:
      model: huggingface/BAAI/bge-reranker-v2-m3
      api_base: http://embeddings:8001
```

然后调用 LiteLLM 的 `/rerank` 接口，它将代理转发到您的自托管重排序服务。

## 保护你的服务器

如果你的向量化服务器可从公网访问 —— 即使只是短暂可达 —— 也请至少采取以下保护措施。向量化请求携带你的文本数据，未做身份验证的接口会同时面临数据泄露和计算资源滥用的风险。

**1. 使用 API 密钥。** 挂载 `/var/lib/embeddings` 数据卷的新安装会自动生成 API 密钥。可用 `docker exec embeddings embed_manage --showkey` 查看；脚本中可用 `docker exec embeddings embed_manage --getkey`。没有密钥的既有安装会保持开放以兼容旧行为；也可以在 `env` 文件中设置 `EMBED_API_KEY` 手动启用认证。所有已认证请求必须包含 `Authorization: Bearer <key>`。如果启用了重排序且未设置 `RERANK_API_KEY`，它会使用 embeddings 密钥。

```bash
# 生成 32 字节的随机密钥
openssl rand -hex 32
```

**2. 在反向代理后面时绑定到 localhost。** 将 `-p 8000:8000` 替换为 `-p 127.0.0.1:8000:8000`（或在 `docker-compose.yml` 中将 `"8000:8000/tcp"` 改为 `"127.0.0.1:8000:8000/tcp"`），使未加密端口无法从主机外部直接访问。如果启用了重排序，端口 `8001` 也做同样处理。

**3. 在代理处限制请求体大小。** 大批量向量化请求可能消耗大量内存；配置反向代理以拒绝过大的请求体（例如 nginx `client_max_body_size 10M;`）。

**4. 注意日志级别。** 详细日志级别可能会将输入文本写入日志。在共享系统上请保持 `INFO` 级别或更高。

**5. 浏览器调用时在代理处启用 CORS。** 本服务器默认不设置 `Access-Control-Allow-Origin` 响应头；若需在不同源的网页中直接调用本 API，请在反向代理处添加 CORS 头。

**6. 考虑限流。** 在服务器前部署限流（如 nginx `limit_req_zone`、Caddy `rate_limit`），限制每个客户端 IP 的并发向量化请求数。

## 使用反向代理

如需面向公网部署，可在向量化服务器前置反向代理处理 HTTPS 终止。在本地或可信网络中使用无需 HTTPS，但将 API 端点暴露在公网时建议启用 HTTPS。

从反向代理访问向量化容器时使用以下地址之一：

- **`embeddings:8000`** — 如果反向代理作为容器运行在与向量化服务器**同一 Docker 网络**中（例如定义在同一 `docker-compose.yml` 中）。
- **`127.0.0.1:8000`** — 如果反向代理运行在**主机上**且端口 `8000` 已发布（默认 `docker-compose.yml` 会发布该端口）。

**使用 [Caddy](https://caddyserver.com/docs/)（[Docker 镜像](https://hub.docker.com/_/caddy)）的示例**（自动 Let's Encrypt TLS，反向代理在同一 Docker 网络中）：

`Caddyfile`：
```
embeddings.example.com {
  reverse_proxy embeddings:8000
}
```

**使用 nginx 的示例**（反向代理运行在主机上）：

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

## 更新 Docker 镜像

如需更新 Docker 镜像和容器，首先[下载](#下载)最新版本：

```bash
docker pull hwdsl2/embeddings-server
```

如果镜像已是最新版本，您将看到：

```
Status: Image is up to date for hwdsl2/embeddings-server:latest
```

否则将下载最新版本。删除并重新创建容器：

```bash
docker rm -f embeddings
# 然后使用相同的数据卷和端口重新运行快速开始中的 docker run 命令。
```

您下载的模型将保留在 `embeddings-data` 数据卷中。

## 与其他 AI 服务配合使用

Embeddings 可作为更广泛的自托管 AI 设置中的嵌入服务。

如需完整和轻量级 Docker Compose 技术栈、手动 `docker run` 示例，以及结合 Kokoro、Embeddings、LiteLLM、Ollama、Docling 和 MCP Gateway 的语音/RAG/MCP 流水线示例，请参阅 [Self-Hosted AI Stack](https://github.com/hwdsl2/self-hosted-ai-stack/blob/main/README-zh.md)。

## 技术细节

- 基础镜像（amd64）：`ghcr.io/huggingface/text-embeddings-inference:cpu-latest`（Debian）
- 基础镜像（arm64）：从 TEI 源码编译，使用 ONNX Runtime + Candle 后端（Debian）
- 向量化引擎：[Hugging Face TEI](https://github.com/huggingface/text-embeddings-inference)（基于 Rust，高性能）
- API：OpenAI 兼容的 `/v1/embeddings` 接口（由 TEI 直接提供；支持的字段取决于 TEI）
- 重排序：TEI `/rerank` 接口，通过加载交叉编码器模型的第二个进程提供
- 数据目录：`/var/lib/embeddings`（Docker 数据卷）
- 模型存储：HuggingFace Hub 格式，存储在数据卷中——下载一次，重启后复用
- 模型管理：Python（`huggingface_hub`）通过 `embed_manage --pullmodel` 预下载

## 授权协议

**注：** 预构建镜像中包含的软件组件（如 Hugging Face TEI 及其依赖项）均受各自版权持有者所选许可证约束。使用预构建镜像时，用户有责任确保其使用方式符合镜像内所有软件的相关许可证要求。

版权所有 (C) 2026 Lin Song   
本作品采用 [MIT 许可证](https://opensource.org/licenses/MIT)授权。

**Hugging Face Text Embeddings Inference (TEI)** 版权归 Hugging Face, Inc. 所有，依据 [Apache 许可证 2.0](https://github.com/huggingface/text-embeddings-inference/blob/main/LICENSE) 分发。

本项目是 Hugging Face TEI 的独立 Docker 封装，与 Hugging Face, Inc. 无关联，未获其背书或赞助。
