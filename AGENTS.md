# Деплой проекта через wlgdev/deploy (v1: headless, без трафика извне)

> Деплой = собрать образ, запушить в `ghcr.io`, вызвать экшен ниже.
> SSH-ключи и хосты тебе не нужны.

## Требования

1. Репозиторий в `wlgdev`, `docker-compose.yml` в корне (или свой путь).
2. Compose ссылается ТОЛЬКО на собранные образы (никакого `build:` на сервере),
   координаты — через переменные: `image: ${SERVICE_IMAGE_NAME}:${SERVICE_IMAGE_TAG}`.
3. Образы пушатся по конвенции:
   - push в `main`/`master` → тег `dev`: `ghcr.io/wlgdev/<app>:dev`
   - published release `vX.Y.Z` → тег релиза: `ghcr.io/wlgdev/<app>:vX.Y.Z`
4. Секрет `DEPLOY_TRIGGER_PAT` в настройках репо (выдаёт мейнтейнер `wlgdev/deploy`).

## Дев: push → стек `<app>-dev`

`.github/workflows/deploy-dev.yml`:

```yaml
name: deploy-dev
on:
  push:
    branches: [main, master]
  workflow_dispatch:
jobs:
  deploy-dev:
    runs-on: ubuntu-latest
    steps:
      - uses: wlgdev/deploy/.github/actions/deploy@main
        with:
          pat: ${{ secrets.DEPLOY_TRIGGER_PAT }}
          env: |
            SERVICE_IMAGE_NAME=ghcr.io/wlgdev/ЗАМЕНИ-app
            SERVICE_IMAGE_TAG=dev
```

## Прод: published release → стек `<app>`

`.github/workflows/deploy-prod.yml`:

```yaml
name: deploy-prod
on:
  release:
    types: [published]
jobs:
  deploy-prod:
    runs-on: ubuntu-latest
    steps:
      - uses: wlgdev/deploy/.github/actions/deploy@main
        with:
          pat: ${{ secrets.DEPLOY_TRIGGER_PAT }}
          is_dev: 'false'
          env: |
            SERVICE_IMAGE_NAME=ghcr.io/wlgdev/ЗАМЕНИ-app
            SERVICE_IMAGE_TAG=${{ github.event.release.tag_name }}
```

## Параметры экшена

| Input | Default | Что это |
|---|---|---|
| `pat` | — | всегда `${{ secrets.DEPLOY_TRIGGER_PAT }}` |
| `docker_compose_path` | `docker-compose.yml` | если compose не в корне |
| `is_dev` | `'true'` | `'false'` → прод-стек `<app>` вместо `<app>-dev` |
| `env` | — | `K=V` построчно → только на время запуска, на диске не хранятся |
| `central_ref` | `main` | не трогать |

## Правила

- Данные в volumes внутри `/data/apps/<app>` переживают редеплои.
- Откат = ручной Run workflow в `wlgdev/deploy` со старым `sha`
  (образ с этим SHA должен существовать).
- Упал деплой — падает и твой run, в логе ссылка на центральный run.
- Версия экшена `@main`; хочешь пин — укажи SHA коммита из `wlgdev/deploy`.
