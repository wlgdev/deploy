# wlgdev/deploy — деплой своих проектов за 5 минут

Деплоит headless-приложения организации (боты, воркеры — всё, что **ничего
не выставляет наружу**). Ты собираешь образ, пушишь в `ghcr.io`, вызываешь
экшен — остальное происходит само на прод-сервере. SSH-ключи и хосты тебе
не нужны, они живут только здесь.

## Как задеплоить свой проект

### 0. Что нужно

- Репозиторий в организации `wlgdev`.
- `docker-compose.yml` (в корне или deeper — укажешь путь).
- Секрет `DEPLOY_TRIGGER_PAT` (шаг 2, одноразово).

### 1. Приготовь docker-compose

Два правила:

1. Никакого `build:` — на сервере только готовые образы.
2. Координаты образа — через переменные:
   `image: ${SERVICE_IMAGE_NAME}:${SERVICE_IMAGE_TAG}`.

Образы пушь по конвенции (тогда ничего лишнего передавать не надо):

- push в `main`/`master` → тег `dev`: `ghcr.io/wlgdev/<твой-проект>:dev`
- published release `v1.2.3` → тег релиза: `ghcr.io/wlgdev/<твой-проект>:v1.2.3`

### 2. Сделай PAT (пошагово, один раз на проект)

1. Жми на аватар → **Settings** → слева внизу **Developer settings** →
   **Personal access tokens** → **Fine-grained tokens** → **Generate new token**.
2. Заполни:
   - **Token name**: `deploy-trigger-<твой-проект>`
   - **Expiration**: `1 year` (потом перевыпустишь — см. ротацию ниже)
   - **Resource owner**: `wlgdev`
   - **Repository access** → **Only select repositories** → выбери **`deploy`**
   - **Permissions** → **Repository permissions** → **Actions** → **Read and write**
3. **Generate token** → скопируй токен (показывается один раз).
4. Иди в СВОЙ репозиторий → **Settings** → **Secrets and variables** →
   **Actions** → **New repository secret**:
   - Name: `DEPLOY_TRIGGER_PAT`, Secret: вставь токен → **Add secret**.

Этот токен умеет только одно — дёргать деплой. Больше ничего.

### 3. Добавь workflow для dev-среды

Файл `.github/workflows/deploy-dev.yml` в своём репо:

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
            SERVICE_IMAGE_NAME=ghcr.io/wlgdev/ЗАМЕНИ-на-свой-проект
            SERVICE_IMAGE_TAG=dev
            МОЯ_ПЕРЕМЕННАЯ=значение
```

Замени `ЗАМЕНИ-на-свой-проект` на имя своего репозитория. Готово.

### 4. Добавь workflow для прода (по желанию)

Файл `.github/workflows/deploy-prod.yml`:

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
            SERVICE_IMAGE_NAME=ghcr.io/wlgdev/ЗАМЕНИ-на-свой-проект
            SERVICE_IMAGE_TAG=${{ github.event.release.tag_name }}
```

### 5. Запушь и смотри

- Зелёный run в СВОЁМ репо = деплой прошёл целиком: экшен дожидается
  центрального деплоя и падает вместе с ним, со ссылкой на его лог.
- Красный — открой лог, там ссылка на упавший центральный run.
- Ручной перезапуск/откат на старый коммит: Actions этого репо → `deploy` →
  **Run workflow** (образ с этим коммитом должен существовать в `ghcr.io`).

## Входные переменные экшена

| Переменная | По умолчанию | Что это |
|---|---|---|
| `pat` | — | всегда `${{ secrets.DEPLOY_TRIGGER_PAT }}` |
| `docker_compose_path` | `docker-compose.yml` | путь до compose внутри твоего репо, корень по умолчанию |
| `is_dev` | `'true'` | `'false'` → прод-стек вместо `-dev` |
| `env` | — | строки `K=V`: пробрасываются в `docker compose` в момент запуска, на диске сервера НЕ хранятся (без переводов строк и `#`-комментариев) |
| `central_ref` | `main` | не трогать |

Версия экшена `@main`; хочешь стабильности — укажи SHA коммита из этого репо.

## Как это работает внутри

1. Твой workflow вызывает экшен → тот шлёт `workflow_dispatch` сюда с
   параметрами (`repo`, `sha`, остальное).
2. Центральный run проверяет: репо из `wlgdev`, имя ок, SHA полный,
   путь без `..`. Чужие репозитории отшиваются здесь.
3. Раннер выкачивает твой репо ровно на `sha`, копирует compose на сервер в
   `/data/apps/<проект>` (dev — в `<проект>-dev`), экспортирует переменные
   и делает `docker compose pull && up -d`.
4. Твои данные живут в volumes внутри `/data/apps/<проект>` и переживают
   редеплои.

## Мейнтейнеру `wlgdev/deploy`

Секреты центра: `DEPLOY_SSH_KEY/HOST/USER/PORT` (ключ юзера `deploy`),
`ORG_READ_PAT` (classic PAT, скоуп `repo`), variable `GHCR_USER`.
В проектах — только `DEPLOY_TRIGGER_PAT` (см. шаг 2 выше).

- Сверка сервера: `ssh root@HOST 'bash -s' < scripts/check-server.sh`
  (для MobaXterm — вставляемый блок в шапке скрипта).
- Ротация SSH: новый ключ → append паблика → обновить секрет → деплой пилота →
  убрать старый паблик. Ротация PAT: перегенерить → обновить секрет → редеплой.
- Публичность репо обязательна: приватный репо ломает `uses:` из других
  проектов. Секреты этим не раскрываются.
