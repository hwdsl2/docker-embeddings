---
name: Bug report
about: Tell us about a problem you are experiencing
title: ''
labels: ''
assignees: ''

---
**Checklist**

- [ ] I read the [README](https://github.com/hwdsl2/docker-embeddings/blob/main/README.md) or the relevant section
- [ ] I searched existing [Issues](https://github.com/hwdsl2/docker-embeddings/issues?q=is%3Aissue)
- [ ] This issue is about the Embeddings Docker image/config/API, not only Hugging Face Text Embeddings Inference itself

<!---
If you found a reproducible bug in the upstream project itself, consider opening an issue upstream: [Text Embeddings Inference](https://github.com/huggingface/text-embeddings-inference).
--->

**Describe the issue**
A clear and concise description of the problem.

**Deployment context**
- [ ] Standalone container
- [ ] Part of [docker-ai-stack](https://github.com/hwdsl2/docker-ai-stack)

**To Reproduce**
Steps to reproduce the behavior:

1. ...
2. ...

**Expected behavior**
A clear and concise description of what you expected to happen.

**Environment**
- Docker host OS: [e.g. Ubuntu 24.04]
- Hosting provider (if applicable): [e.g. AWS, GCP, home server]
- CPU architecture: [e.g. amd64, arm64]
- Image/tag: [e.g. `hwdsl2/embeddings-server:latest`]
- Start method: [docker run / docker compose / other]
- Published port(s): [8000 embeddings, 8001 rerank]

**Configuration**
Remove secrets, API keys, tokens and private URLs before posting.

- Env file or variables changed: [embed.env / `-e` / compose `environment`]
- Docker run or compose changes:

**Service details**
- Mode involved: embeddings, rerank, or both:
- Model/reranker name:
- Request shape and approximate input size:
- Active `EMBED_*` / `RERANK_*` settings:
- Management command output, if relevant (for example `docker exec embeddings embed_manage --showinfo`):
- Model download/cache or memory issue details, if relevant:

**Logs**
Add relevant logs with secrets removed.

```bash
docker logs embeddings
```

If using Docker Compose, you can also include:

```bash
docker compose logs embeddings
```

**Additional context**
Add any other context about the problem here.
