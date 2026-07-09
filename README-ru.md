[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# API текстовых эмбеддингов и переранжирования на Docker

[![Статус сборки](https://github.com/hwdsl2/docker-embeddings/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-embeddings/actions/workflows/main.yml) &nbsp;[![Docker Pulls](https://raw.githubusercontent.com/hwdsl2/badges/main/img/docker-pulls-embeddings-server.svg)](https://hub.docker.com/r/hwdsl2/embeddings-server) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

Часть [Self-Hosted AI Stack](https://github.com/hwdsl2/self-hosted-ai-stack/blob/main/README-ru.md) — разверните полный самостоятельно размещённый AI-стек одной командой.

Docker-образ для запуска самостоятельно размещённого сервера текстовых эмбеддингов и переранжирования на базе [Hugging Face Text Embeddings Inference (TEI)](https://github.com/huggingface/text-embeddings-inference). Предоставляет совместимый с OpenAI API `/v1/embeddings` и эндпоинт `/rerank`. Простой, приватный, для самостоятельного развёртывания.

**Возможности:**

- Совместимый с OpenAI эндпоинт `POST /v1/embeddings` — любое приложение, использующее OpenAI Embeddings API, переключается с изменением одной строки
- На базе [Hugging Face TEI](https://github.com/huggingface/text-embeddings-inference) — высокопроизводительного сервера эмбеддингов на Rust
- Поддержка популярных моделей: `BAAI/bge-small-en-v1.5`, `BAAI/bge-m3`, `nomic-embed-text-v1.5` и других
- Опциональное переранжирование через `POST /rerank` — включите cross-encoder модель для повторной оценки найденных документов и повышения точности поиска
- Управление моделями через вспомогательный скрипт (`embed_manage`)
- Текстовые данные остаются на вашем сервере — никакие данные не отправляются третьим сторонам
- Офлайн-режим — работа без доступа к интернету с предварительно кэшированными моделями (`EMBED_LOCAL_ONLY`)
- Автоматически собирается и публикуется через [GitHub Actions](https://github.com/hwdsl2/docker-embeddings/actions/workflows/main.yml)
- Постоянный кэш моделей через Docker-том
- Поддерживаемые платформы: `linux/amd64`, `linux/arm64`

**Также доступно:**

- AI-стек: [Self-Hosted AI Stack](https://github.com/hwdsl2/self-hosted-ai-stack/blob/main/README-ru.md)
- Связанные AI-сервисы: [Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-ru.md), [Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-ru.md), [LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-ru.md), [Ollama (LLM)](https://github.com/hwdsl2/docker-ollama/blob/main/README-ru.md), [Docling](https://github.com/hwdsl2/docker-docling/blob/main/README-ru.md), [MCP Gateway](https://github.com/hwdsl2/docker-mcp-gateway/blob/main/README-ru.md)

## Сообщество

- 📬 [Подписаться на обновления проектов](https://selfhostedstack.beehiiv.com/subscribe?utm_campaign=ai-ru) (1–2 письма в месяц) — получить бесплатные руководства по развёртыванию AI и VPN (PDF, на английском)
- 💬 Присоединяйтесь к сообществу [r/selfhostedstack](https://www.reddit.com/r/selfhostedstack/) для обсуждений и демонстрации проектов
- ⭐ Поставьте звезду репозиторию, если он оказался вам полезен — это поможет другим пользователям его найти.

<details>
<summary>Самостоятельно размещаемые VPN и сетевые проекты</summary>

- [Setup IPsec VPN](https://github.com/hwdsl2/setup-ipsec-vpn/blob/master/README-ru.md)
- [IPsec VPN на Docker](https://github.com/hwdsl2/docker-ipsec-vpn-server/blob/master/README-ru.md)
- [WireGuard](https://github.com/hwdsl2/docker-wireguard/blob/main/README-ru.md)
- [OpenVPN](https://github.com/hwdsl2/docker-openvpn/blob/main/README-ru.md)
- [Headscale](https://github.com/hwdsl2/docker-headscale/blob/main/README-ru.md)

</details>

## Быстрый старт

Запустите сервер текстовых эмбеддингов следующей командой:

```bash
docker run \
    --name embeddings \
    --restart=always \
    -v embeddings-data:/var/lib/embeddings \
    -p 8000:8000 \
    -d hwdsl2/embeddings-server
```

**Примечание:** Для развёртываний, доступных из интернета, **настоятельно рекомендуется** добавить HTTPS с помощью [обратного прокси](#использование-обратного-прокси). В этом случае также замените `-p 8000:8000` на `-p 127.0.0.1:8000:8000` в команде `docker run` выше, чтобы исключить прямой доступ к незашифрованному порту извне.

При первом запуске модель по умолчанию `BAAI/bge-small-en-v1.5` (~130 МБ) автоматически загружается и кэшируется. Проверьте логи, чтобы убедиться в готовности сервера:

```bash
docker logs embeddings
```

После появления сообщения "Text embeddings server is ready" сгенерируйте первые эмбеддинги:

```bash
curl http://IP_вашего_сервера:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "The quick brown fox", "model": "text-embedding-ada-002"}'
```

**Ответ:**
```json
{"object":"list","data":[{"object":"embedding","embedding":[0.032,...,-0.017],"index":0}],"model":"BAAI/bge-small-en-v1.5","usage":{"prompt_tokens":5,"total_tokens":5}}
```

## Требования

- Linux-сервер (локальный или облачный) с установленным Docker
- Поддерживаемые архитектуры: `amd64` (x86_64), `arm64` (aarch64, например AWS Graviton, Apple Silicon VM)
- Минимальный объём оперативной памяти: ~250 МБ для модели по умолчанию `BAAI/bge-small-en-v1.5` (см. [таблицу моделей](#смена-модели))
- Доступ к интернету для первоначальной загрузки модели (после загрузки модель кэшируется локально). Не требуется при использовании `EMBED_LOCAL_ONLY=true` с предварительно кэшированными моделями.

Для развёртываний, доступных из интернета, см. [Использование обратного прокси](#использование-обратного-прокси) для добавления HTTPS.

## Загрузка

Получите надёжную сборку из [реестра Docker Hub](https://hub.docker.com/r/hwdsl2/embeddings-server/):

```bash
docker pull hwdsl2/embeddings-server
```

Также можно загрузить с [Quay.io](https://quay.io/repository/hwdsl2/embeddings-server):

```bash
docker pull quay.io/hwdsl2/embeddings-server
docker image tag quay.io/hwdsl2/embeddings-server hwdsl2/embeddings-server
```

Поддерживаемые платформы: `linux/amd64`, `linux/arm64`.

## Переменные окружения

Все переменные являются необязательными. Новые установки с подключённым томом `/var/lib/embeddings` автоматически генерируют Bearer-токен. Существующие установки без ключа остаются открытыми для обратной совместимости.

Данный Docker-образ использует следующие переменные, которые можно задать в файле `env` (см. [пример](embed.env.example)):

| Переменная | Описание | По умолчанию |
|---|---|---|
| `EMBED_MODEL` | ID модели HuggingFace для генерации эмбеддингов. См. [таблицу моделей](#смена-модели). | `BAAI/bge-small-en-v1.5` |
| `EMBED_PORT` | HTTP-порт для API (1–65535). | `8000` |
| `EMBED_API_KEY` | Опциональный Bearer-токен. В новых постоянных установках генерируется автоматически. Если задан, все API-запросы должны содержать `Authorization: Bearer <key>`. Явно пустое значение отключает аутентификацию. | Автоматически для новых постоянных установок |
| `EMBED_HF_TOKEN` | Токен HuggingFace Hub для доступа к приватным или ограниченным моделям. Не требуется для публичных моделей. | *(не задан)* |
| `EMBED_LOCAL_ONLY` | При установке любого непустого значения (например, `true`) отключает все загрузки моделей с HuggingFace. Для офлайн- или изолированных развёртываний с предварительно кэшированными моделями. | *(не задан)* |
| `EMBED_ENABLED` | Установите `false` для отключения процесса эмбеддингов (для режима «только переранжирование»). | `true` |
| `RERANK_ENABLED` | Установите `true` для запуска сервера переранжирования (cross-encoder модель на отдельном порту). | *(не задан)* |
| `RERANK_MODEL` | ID модели HuggingFace cross-encoder для переранжирования. См. [модели переранжирования](#переранжирование). | `BAAI/bge-reranker-v2-m3` |
| `RERANK_PORT` | HTTP-порт для API переранжирования. По умолчанию `8000`, если эмбеддинги отключены. | `8001` |
| `RERANK_API_KEY` | Опциональный Bearer-токен для переранжирования. Если не задан, используется `EMBED_API_KEY`. Явно пустое значение отключает аутентификацию reranker. | *(использует `EMBED_API_KEY`)* |
| `EMBED_DISABLE_USAGE_COUNTS` | Установите `1`, чтобы отключить анонимные агрегированные счётчики использования. | *(не задан)* |

**Примечание:** В файле `env` значения можно заключать в одинарные кавычки, например `VAR='value'`. Не используйте пробелы вокруг `=`. При изменении `EMBED_PORT` обновите флаг `-p` в команде `docker run` соответствующим образом.

Пример использования файла `env`:

```bash
cp embed.env.example embed.env
# Отредактируйте embed.env, задав нужные параметры, затем:
docker run \
    --name embeddings \
    --restart=always \
    -v embeddings-data:/var/lib/embeddings \
    -v ./embed.env:/embed.env:ro \
    -p 8000:8000 \
    -d hwdsl2/embeddings-server
```

Файл `env` монтируется в контейнер и применяется при каждом перезапуске без необходимости пересоздавать контейнер.

<details>
<summary>Также можно передать его через <code>--env-file</code></summary>

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

## Использование docker-compose

```bash
cp embed.env.example embed.env
# Отредактируйте embed.env при необходимости, затем:
docker compose up -d
docker logs embeddings
```

Пример `docker-compose.yml` (уже включён в проект):

```yaml
services:
  embeddings:
    image: hwdsl2/embeddings-server
    container_name: embeddings
    restart: always
    ports:
      - "8000:8000/tcp"  # Для хост-обратного прокси замените на "127.0.0.1:8000:8000/tcp"
      # - "8001:8001/tcp"  # API переранжирования (раскомментируйте при RERANK_ENABLED=true в embed.env)
    volumes:
      - embeddings-data:/var/lib/embeddings
      - ./embed.env:/embed.env:ro

volumes:
  embeddings-data:
    name: embeddings-data
```

**Примечание:** Для развёртываний, доступных из интернета, настоятельно рекомендуется добавить HTTPS с помощью [обратного прокси](#использование-обратного-прокси). В этом случае замените `"8000:8000/tcp"` на `"127.0.0.1:8000:8000/tcp"` в `docker-compose.yml`, чтобы исключить прямой доступ к незашифрованному порту.

## Справочник по API

API совместим с [эндпоинтом эмбеддингов OpenAI](https://platform.openai.com/docs/api-reference/embeddings). Любое приложение, уже вызывающее `https://api.openai.com/v1/embeddings`, может переключиться на самостоятельный хостинг, задав:

Эндпоинт `/v1/embeddings` предоставляется напрямую TEI. Поддерживаемые поля запросов OpenAI зависят от TEI; такие поля, как `encoding_format`, `dimensions`, `user`, а также входные token-массивы зависят от upstream-реализации и не документируются и не тестируются этим образом.

```
OPENAI_BASE_URL=http://IP_вашего_сервера:8000
```

### Генерация эмбеддингов

```
POST /v1/embeddings
Content-Type: application/json
```

**Параметры:**

| Параметр | Тип | Обязательный | Описание |
|---|---|---|---|
| `input` | строка или массив | ✅ | Текст для преобразования в эмбеддинг. Строка — для одного текста, массив строк — для пакетной обработки. |
| `model` | строка | ✅ | Передайте любую строку (например, `text-embedding-ada-002`). Значение принимается для совместимости с API; всегда используется активная модель, заданная в `EMBED_MODEL`. |

**Пример — одиночный запрос:**

```bash
curl http://IP_вашего_сервера:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "The quick brown fox", "model": "text-embedding-ada-002"}'
```

**Пример — пакетный запрос:**

```bash
curl http://IP_вашего_сервера:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": ["Первое предложение", "Второе предложение"], "model": "text-embedding-ada-002"}'
```

С аутентификацией по API-ключу:

```bash
curl http://IP_вашего_сервера:8000/v1/embeddings \
    -H "Authorization: Bearer your_api_key" \
    -H "Content-Type: application/json" \
    -d '{"input": "Ваш текст здесь", "model": "text-embedding-ada-002"}'
```

**Ответ:**

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

### Информация о модели

```
GET /info
```

Возвращает ID активной модели, максимальную длину входного текста и версию сервера.

```bash
curl http://IP_вашего_сервера:8000/info
```

### Переранжирование документов

> Требуется `RERANK_ENABLED=true` в файле env. Переранжирование работает на порту 8001 по умолчанию.

```
POST /rerank
Content-Type: application/json
```

**Параметры:**

| Параметр | Тип | Обязательный | Описание |
|---|---|---|---|
| `query` | строка | ✅ | Поисковый запрос для ранжирования документов. |
| `texts` | массив строк | ✅ | Документы для переранжирования. |
| `raw_scores` | булево | | Если `true`, возвращает необработанные оценки cross-encoder вместо нормализованных. По умолчанию: `false`. |
| `truncate` | булево | | Если `true`, обрезает входные данные, превышающие максимальную длину модели. По умолчанию: `true`. |

**Пример:**

```bash
curl http://IP_вашего_сервера:8001/rerank \
    -H "Content-Type: application/json" \
    -d '{
      "query": "Что такое глубокое обучение?",
      "texts": [
        "Глубокое обучение — это подмножество машинного обучения...",
        "Сегодня солнечная погода, температура до 25°C.",
        "Нейронные сети вдохновлены устройством человеческого мозга."
      ],
      "raw_scores": false
    }'
```

**Ответ:**

```json
[
  {"index": 0, "score": 0.98},
  {"index": 2, "score": 0.72},
  {"index": 1, "score": 0.01}
]
```

Результаты отсортированы по убыванию оценки релевантности (наиболее релевантный первый). Используйте для переоценки документов, полученных при поиске по эмбеддингам.

### Интерактивная документация по API

Интерактивный Swagger UI доступен по адресу:

```
http://IP_вашего_сервера:8000/docs
```

Если переранжирование включено, у него также есть собственная интерактивная документация:

```
http://IP_вашего_сервера:8001/docs
```

## Постоянные данные

Все данные сервера хранятся в Docker-томе (`/var/lib/embeddings` внутри контейнера):

```
/var/lib/embeddings/
├── models--BAAI--bge-small-en-v1.5/   # Кэшированные файлы модели эмбеддингов
├── models--BAAI--bge-reranker-v2-m3/  # Кэшированные файлы модели переранжирования (если включено)
├── .port                # Активный порт (используется embed_manage)
├── .model               # ID активной модели (используется embed_manage)
├── .rerank_model        # Активная модель переранжирования (используется embed_manage)
├── .rerank_port         # Активный порт переранжирования (используется embed_manage)
└── .server_addr         # Кэшированный IP сервера (используется embed_manage)
```

Создайте резервную копию Docker-тома для сохранения загруженных моделей. Размер моделей — от ~90 МБ до ~1.3 ГБ; они загружаются только один раз, а сохранение тома позволяет избежать повторной загрузки при пересоздании контейнера.

## Управление сервером

Используйте `embed_manage` внутри работающего контейнера для проверки и управления сервером.

**Показать информацию о сервере:**

```bash
docker exec embeddings embed_manage --showinfo
```

**Список рекомендуемых моделей:**

```bash
docker exec embeddings embed_manage --listmodels
```

**Список рекомендуемых моделей переранжирования:**

```bash
docker exec embeddings embed_manage --listrerankers
```

**Предварительная загрузка модели:**

```bash
docker exec embeddings embed_manage --pullmodel BAAI/bge-base-en-v1.5
docker exec embeddings embed_manage --pullmodel BAAI/bge-reranker-v2-m3
```

## Смена модели

Для смены активной модели:

1. *(Необязательно, но рекомендуется)* Предварительно загрузите новую модель, пока сервер работает:
   ```bash
   docker exec embeddings embed_manage --pullmodel BAAI/bge-base-en-v1.5
   ```

2. Обновите `EMBED_MODEL` в файле `embed.env` (или добавьте `-e EMBED_MODEL=BAAI/bge-base-en-v1.5` в команду `docker run`).

3. Перезапустите контейнер:
   ```bash
   docker restart embeddings
   ```

**Рекомендуемые модели:**

| Модель | Диск | ОЗУ (прибл.) | Примечания |
|---|---|---|---|
| `BAAI/bge-small-en-v1.5` | ~130 МБ | ~250 МБ | Самая быстрая; английский — **по умолчанию** |
| `BAAI/bge-base-en-v1.5` | ~440 МБ | ~700 МБ | Хороший баланс; английский |
| `BAAI/bge-large-en-v1.5` | ~1.3 ГБ | ~2 ГБ | Высокая точность; английский |
| `BAAI/bge-m3` | ~570 МБ | ~1 ГБ | Многоязычный; кросс-языковой поиск |
| `nomic-ai/nomic-embed-text-v1.5` | ~550 МБ | ~1 ГБ | Многоязычный; длинный контекст (8192 токена) |
| `sentence-transformers/all-MiniLM-L6-v2` | ~90 МБ | ~200 МБ | Очень компактная; быстрая; популярна для семантического поиска |

> **Совет:** Для неанглоязычных или многоязычных задач рекомендуется использовать `BAAI/bge-m3` или `nomic-ai/nomic-embed-text-v1.5`. Для RAG-конвейеров на английском языке `BAAI/bge-base-en-v1.5` обеспечивает хороший баланс между точностью и потреблением ресурсов.

Модели кэшируются в Docker-томе `/var/lib/embeddings` и загружаются только один раз. Можно использовать любую модель HuggingFace, поддерживаемую TEI — см. [список поддерживаемых моделей TEI](https://huggingface.co/models?pipeline_tag=feature-extraction).

## Переранжирование

Переранжирование повышает качество поиска, переоценивая документы с помощью cross-encoder модели. Включите его, задав `RERANK_ENABLED=true` в файле env.

### Быстрая настройка

1. Добавьте в `embed.env`:
   ```bash
   RERANK_ENABLED=true
   ```

2. Откройте порт 8001 (добавьте `-p 8001:8001` в команду `docker run` или раскомментируйте порт в `docker-compose.yml`).

3. Перезапустите контейнер:
   ```bash
   docker restart embeddings
   ```

Модель переранжирования (`BAAI/bge-reranker-v2-m3`, ~560 МБ) загружается при первом запуске.

### Режимы работы

| Режим | Конфигурация | ОЗУ (прибл.) |
|---|---|---|
| Только эмбеддинги (по умолчанию) | `RERANK_ENABLED` не задан | ~250 МБ (bge-small) |
| Эмбеддинги + Переранжирование | `RERANK_ENABLED=true` | ~850 МБ (bge-small + bge-reranker-v2-m3) |
| Только переранжирование | `EMBED_ENABLED=false`, `RERANK_ENABLED=true` | ~600 МБ (bge-reranker-v2-m3) |

В режиме **«только переранжирование»** сервер переранжирования по умолчанию слушает порт 8000 (так как процесс эмбеддингов отключён), если `RERANK_PORT` не задан явно.

### Рекомендуемые модели переранжирования

| Модель | Диск | ОЗУ (прибл.) | Примечания |
|---|---|---|---|
| `BAAI/bge-reranker-v2-m3` | ~560 МБ | ~600 МБ | Многоязычная; высокая точность — **по умолчанию** |
| `BAAI/bge-reranker-base` | ~440 МБ | ~500 МБ | Английский; хороший баланс |
| `BAAI/bge-reranker-large` | ~1.3 ГБ | ~1.5 ГБ | Английский; наивысшая точность |
| `cross-encoder/ms-marco-MiniLM-L6-v2` | ~90 МБ | ~150 МБ | Очень компактная; быстрая; английский |

### Использование с LiteLLM

Для использования переранжирования с [LiteLLM](https://github.com/hwdsl2/docker-litellm) добавьте его как модель в конфигурацию LiteLLM:

```yaml
model_list:
  - model_name: rerank
    litellm_params:
      model: huggingface/BAAI/bge-reranker-v2-m3
      api_base: http://embeddings:8001
```

Затем вызывайте эндпоинт `/rerank` LiteLLM — он будет проксировать запросы на ваш самостоятельно размещённый сервер переранжирования.

## Защита сервера

Если ваш сервер эмбеддингов доступен из публичной сети — даже кратковременно — примените как минимум следующие меры защиты. Запросы на эмбеддинги содержат ваши текстовые данные, поэтому неаутентифицированная конечная точка создаёт риски как утечки данных, так и злоупотребления вычислительными ресурсами.

**1. Используйте API-ключ.** Новые установки с подключённым томом `/var/lib/embeddings` автоматически генерируют API-ключ. Его можно посмотреть командой `docker exec embeddings embed_manage --showkey`; в скриптах используйте `docker exec embeddings embed_manage --getkey`. Существующие установки без ключа остаются открытыми для обратной совместимости; также можно задать `EMBED_API_KEY` в env-файле вручную. Все аутентифицированные запросы должны содержать `Authorization: Bearer <key>`. Если reranker включён и `RERANK_API_KEY` не задан, он использует ключ embeddings.

```bash
# Сгенерировать 32-байтовый случайный ключ
openssl rand -hex 32
```

**2. Привяжите к localhost при использовании обратного прокси.** Замените `-p 8000:8000` на `-p 127.0.0.1:8000:8000` (или измените `"8000:8000/tcp"` на `"127.0.0.1:8000:8000/tcp"` в `docker-compose.yml`), чтобы незашифрованный порт нельзя было достичь напрямую снаружи хоста. Если переранжирование включено, сделайте то же самое для порта `8001`.

**3. Ограничьте размер тела запроса на прокси.** Большие пакетные запросы на эмбеддинги могут потреблять значительный объём памяти; настройте обратный прокси на отклонение слишком больших тел запросов (например, nginx `client_max_body_size 10M;`).

**4. Следите за уровнем журналирования.** Подробные уровни журналирования могут записывать входной текст в журналы. Сохраняйте уровень сервера `INFO` или выше на общих системах.

**5. Включите CORS на прокси при вызове из браузера.** Сервер по умолчанию не устанавливает заголовки `Access-Control-Allow-Origin`; добавьте их на обратном прокси, если планируете вызывать API напрямую с веб-страницы другого источника.

**6. Рассмотрите ограничение частоты запросов.** Разместите перед сервером ограничитель частоты (например, nginx `limit_req_zone`, Caddy `rate_limit`), чтобы ограничить количество одновременных запросов на эмбеддинги на один IP-адрес клиента.

## Использование обратного прокси

Для развёртываний, доступных из интернета, разместите обратный прокси перед сервером эмбеддингов для обработки HTTPS-терминации. Сервер работает без HTTPS в локальной или доверенной сети, но HTTPS рекомендуется при открытом доступе из интернета.

Используйте один из следующих адресов для доступа к контейнеру эмбеддингов из обратного прокси:

- **`embeddings:8000`** — если обратный прокси запущен в одной **Docker-сети** с сервером эмбеддингов (например, в одном `docker-compose.yml`).
- **`127.0.0.1:8000`** — если обратный прокси работает **на хосте** и порт `8000` опубликован (по умолчанию `docker-compose.yml` его публикует).

**Пример с [Caddy](https://caddyserver.com/docs/) ([Docker-образ](https://hub.docker.com/_/caddy))** (автоматический TLS через Let's Encrypt, обратный прокси в той же Docker-сети):

`Caddyfile`:
```
embeddings.example.com {
  reverse_proxy embeddings:8000
}
```

**Пример с nginx** (обратный прокси на хосте):

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

## Обновление Docker-образа

Для обновления Docker-образа и контейнера сначала [загрузите](#загрузка) последнюю версию:

```bash
docker pull hwdsl2/embeddings-server
```

Если образ уже актуален, вы увидите:

```
Status: Image is up to date for hwdsl2/embeddings-server:latest
```

В противном случае будет загружена последняя версия. Удалите и пересоздайте контейнер:

```bash
docker rm -f embeddings
# Затем повторно выполните команду docker run из раздела «Быстрый старт» с теми же томом и портом.
```

Загруженные модели сохраняются в томе `embeddings-data`.

## Использование с другими AI-сервисами

Embeddings можно использовать как службу эмбеддингов в более широком self-hosted AI-стеке.

Готовые полные и облегчённые стеки Docker Compose, примеры ручного запуска через `docker run`, а также примеры голосовых, RAG- и MCP-конвейеров с Kokoro, Embeddings, LiteLLM, Ollama, Docling и MCP Gateway см. в [Self-Hosted AI Stack](https://github.com/hwdsl2/self-hosted-ai-stack/blob/main/README-ru.md).

## Счётчики использования

Этот образ использует публичные счётчики скачиваний GitHub Release assets для анонимной агрегированной статистики использования. Эти числа приблизительны и не являются количеством уникальных пользователей или активных установок. Образ не отправляет telemetry payload и не использует частный сборщик. Он выполняет только best-effort запрос после успешного запуска сервера с подключённым томом `/var/lib/embeddings`, а также при первом запуске другой сборки образа для этой постоянной установки. Чтобы отключить это, задайте `EMBED_DISABLE_USAGE_COUNTS=1`.

## Технические подробности

- Базовый образ (amd64): `ghcr.io/huggingface/text-embeddings-inference:cpu-latest` (Debian)
- Базовый образ (arm64): собирается из исходников TEI с бэкендами ONNX Runtime + Candle (Debian)
- Движок эмбеддингов: [Hugging Face TEI](https://github.com/huggingface/text-embeddings-inference) (на Rust, высокая производительность)
- API: совместимый с OpenAI эндпоинт `/v1/embeddings` (предоставляется напрямую TEI; поддерживаемые поля зависят от TEI)
- Переранжирование: TEI эндпоинт `/rerank` через второй процесс с загруженной cross-encoder моделью
- Директория данных: `/var/lib/embeddings` (Docker-том)
- Хранилище моделей: формат HuggingFace Hub внутри тома — загружается один раз, переиспользуется при перезапусках
- Управление моделями: Python (`huggingface_hub`) для предварительной загрузки через `embed_manage --pullmodel`

## Лицензия

**Примечание:** Программные компоненты внутри готового образа (такие как Hugging Face TEI и его зависимости) лицензированы в соответствии с условиями, выбранными соответствующими правообладателями. При использовании готового образа пользователь несёт ответственность за соблюдение всех применимых лицензий программного обеспечения, входящего в состав образа.

Copyright (C) 2026 Lin Song   
Данная работа распространяется под [лицензией MIT](https://opensource.org/licenses/MIT).

**Hugging Face Text Embeddings Inference (TEI)** является собственностью Hugging Face, Inc. и распространяется под [лицензией Apache 2.0](https://github.com/huggingface/text-embeddings-inference/blob/main/LICENSE).

Данный проект является независимой Docker-обёрткой для Hugging Face TEI и не аффилирован с Hugging Face, Inc., не одобрен и не спонсируется ею.
