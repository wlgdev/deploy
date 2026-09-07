# Деплой проекта через wlgdev/deploy (v1: headless, без трафика извне)

> Деплой = собрать образ, запушить в `ghcr.io`, вызвать экшен ниже.
> SSH-ключи и хосты тебе не нужны.

## Требования

1. Репозиторий в `wlgdev`, `docker-compose.yml` в корне (или свой путь).
2. Compose ссылается ТОЛЬКО на собранные образы (никакого `build:` на сервере).
   Конвенция для своих образов (не обязаловка): `image: ${SERVICE_IMAGE_NAME}:${SERVICE_IMAGE_TAG}` —
   один файл едет и в dev, и в прод, а образы там разные. Имя и тег подставятся сами
   (см. таблицу), хочешь другое — передай `service_image_name` / `service_image_tag`.
   Сторонние образы хардкодь как есть (`image: postgres:16`),
   мультисервис — своими переменными на сервис.
3. Сборка и пуш образа — через наш publish-экшен (логин в `ghcr.io` внутри, теги и чистка старых версий — сами):
   ```yaml
   - uses: actions/checkout@v7
   - uses: wlgdev/deploy/.github/actions/publish@main
     with:
       is_dev: "true"   # 'false' — на релизе
   ```
   В workflow нужны `permissions: contents:read, packages:write, actions:write`.
   Dockerfile не в корне — передай `dockerfile: 'docker/Dockerfile'` (контекст всегда корень репо).
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
```

Имя (`ghcr.io/wlgdev/<твой-проект>`) и тег (короткий sha) подставятся сами.
Свои секреты — через `env: |` строками `K=V`.

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
```

Тег релиза подставится сам.

## Параметры экшена

| Input | Default | Что это |
|---|---|---|
| `pat` | — | всегда `${{ secrets.DEPLOY_TRIGGER_PAT }}` |
| `docker_compose_path` | `docker-compose.yml` | если compose не в корне |
| `is_dev` | `'true'` | `'false'` → прод-стек `<app>` вместо `<app>-dev` |
| `target` | — | `SUBDOMAIN:SERVICE:PORT` для Traefik (пусто = headless) |
| `service_image_name` | `ghcr.io/wlgdev/<твой-проект>` | какой образ тянуть; свой registry — передай явно |
| `service_image_tag` | короткий sha (на релизе — тег релиза) | какой тег тянуть; переопредели, если тегаешь иначе |
| `env` | — | `K=V` построчно → только на время запуска, на диске не хранятся |
| `central_ref` | `main` | не трогать |

## Правила

- Данные в volumes внутри `/data/apps/<app>` переживают редеплои.
- Откат = ручной Run workflow в `wlgdev/deploy` со старым `sha`
  (образ с этим SHA должен существовать).
- Упал деплой — падает и твой run, в логе ссылка на центральный run.
- Версия экшена `@main`; хочешь пин — укажи SHA коммита из `wlgdev/deploy`.
