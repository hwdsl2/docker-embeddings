#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

FROM ghcr.io/huggingface/text-embeddings-inference:cpu-latest

WORKDIR /opt/src

# Install Python (for manage.sh model pre-download) and curl (for health checks).
# python3-venv provides the venv module; python3-pip ensures pip is available
# on Debian Bookworm where ensurepip may be stripped from the slim base image.
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-venv python3-pip curl \
    && python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir --uploaded-prior-to P3D huggingface_hub \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/lib/embeddings

COPY ./run.sh /opt/src/run.sh
COPY ./manage.sh /opt/src/manage.sh
COPY ./LICENSE.md /opt/src/LICENSE.md
RUN chmod 755 /opt/src/run.sh /opt/src/manage.sh \
    && ln -s /opt/src/manage.sh /usr/local/bin/embed_manage

EXPOSE 8000/tcp 8001/tcp
VOLUME ["/var/lib/embeddings"]
ENTRYPOINT []
CMD ["/opt/src/run.sh"]

ARG BUILD_DATE
ARG VERSION
ARG VCS_REF
ENV IMAGE_VER=$BUILD_DATE

LABEL maintainer="Lin Song <linsongui@gmail.com>" \
    org.opencontainers.image.created="$BUILD_DATE" \
    org.opencontainers.image.version="$VERSION" \
    org.opencontainers.image.revision="$VCS_REF" \
    org.opencontainers.image.authors="Lin Song <linsongui@gmail.com>" \
    org.opencontainers.image.title="Text Embeddings & Reranking API on Docker" \
    org.opencontainers.image.description="Docker image to run a self-hosted text embeddings and reranking server powered by Hugging Face TEI, providing an OpenAI-compatible /v1/embeddings API and a /rerank endpoint." \
    org.opencontainers.image.url="https://github.com/hwdsl2/docker-embeddings" \
    org.opencontainers.image.source="https://github.com/hwdsl2/docker-embeddings" \
    org.opencontainers.image.documentation="https://github.com/hwdsl2/docker-embeddings"
