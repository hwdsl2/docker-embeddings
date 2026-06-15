---
name: 错误报告
about: 请使用这个模板来提交 bug
title: ''
labels: ''
assignees: ''

---
**任务列表**

- [ ] 我已阅读[自述文件](https://github.com/hwdsl2/docker-embeddings/blob/main/README-zh.md)或相关章节
- [ ] 我搜索了已有的 [Issues](https://github.com/hwdsl2/docker-embeddings/issues?q=is%3Aissue)
- [ ] 这个问题是关于 Embeddings Docker 镜像/配置/API，而不只是 Hugging Face Text Embeddings Inference 本身

<!---
如果你确认问题属于上游项目本身，请考虑在相应上游项目提交 issue：[Text Embeddings Inference](https://github.com/huggingface/text-embeddings-inference)。
--->

**问题描述**
使用清楚简明的语言描述这个问题。

**部署场景**
- [ ] 独立容器
- [ ] 属于 [self-hosted-ai-stack](https://github.com/hwdsl2/self-hosted-ai-stack/blob/main/README-zh.md)

**重现步骤**
重现该问题的步骤：

1. ...
2. ...

**期待的正确结果**
简要描述你期望发生的结果。

**环境**
- Docker 主机操作系统: [例如 Ubuntu 24.04]
- 服务提供商（如果适用）: [例如 AWS, GCP, 家用服务器]
- CPU 架构: [例如 amd64, arm64]
- 镜像/标签: [例如 `hwdsl2/embeddings-server:latest`]
- 启动方式: [docker run / docker compose / 其它]
- 发布的端口: [8000 embeddings, 8001 rerank]

**配置**
发布前请删除 secrets、API keys、tokens 和私有 URL。

- 修改过的 env 文件或变量: [embed.env / `-e` / compose `environment`]
- Docker run 或 compose 修改：

**服务细节**
- 涉及的模式：embeddings、rerank 或两者：
- 模型/重排模型名称：
- 请求格式和大致输入大小：
- 当前 `EMBED_*` / `RERANK_*` 设置：
- 相关管理命令输出（例如 `docker exec embeddings embed_manage --showinfo`）：
- 模型下载/缓存或内存问题细节（如果相关）：

**日志**
请添加相关日志，并删除敏感信息。

```bash
docker logs embeddings
```

如果使用 Docker Compose，也可以包含：

```bash
docker compose logs embeddings
```

**其它信息**
添加关于该问题的其它信息。
