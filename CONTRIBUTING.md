# Contributing

Thanks for helping improve this project. This repository maintains the Docker image for the embeddings service; changes that only affect multi-service orchestration belong in [self-hosted-ai-stack](https://github.com/hwdsl2/self-hosted-ai-stack).

## Before You Start

- Search existing issues and pull requests.
- Keep changes focused and easy to review.
- For upstream model/runtime behavior, check the upstream project first.
- Do not include API keys, private text, model files, logs with secrets, or provider credentials.

## Pull Requests

- Update `README.md`, env examples, or compose examples when behavior changes.
- Include the Docker image/tag, architecture, and model/runtime path tested.
- For upstream version changes, link the upstream release, tag, or commit.

## Testing

Test the smallest relevant path before opening a PR, for example:

- Build or run the affected image when Dockerfile/runtime behavior changes.
- Exercise the embeddings API or helper script touched by the change.
- Check model download/cache behavior when changing model defaults.
- Run ShellCheck when editing shell scripts.
