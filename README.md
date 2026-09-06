# wlgdev/deploy

Централизованная система автоматического деплоя headless-приложений (ботов, фоновых воркеров и сервисов без входящего HTTP-трафика) для организации `wlgdev`.

Вам **не требуются** SSH-ключи, адреса или пароли от сервера. Всё, что нужно вашему репозиторию — собрать Docker-образ, отправить его в реестр `ghcr.io` и вызвать готовый Action.

---

## Пошаговое руководство (Быстрый старт)

### Шаг 1. Подготовьте `docker-compose.yml`

Создайте файл `docker-compose.yml` в корне вашего репозитория.

Требования к файлу:
1. **Без локальной сборки**: не используйте блок `build:`. На сервере запускаются только готовые образы из реестра.
2. **Шаблон имени образа**: используйте переменные `${SERVICE_IMAGE_NAME}:${SERVICE_IMAGE_TAG}` — система деплоя автоматически передаст актуальные значения для dev и prod.

Пример минимального `docker-compose.yml`:

```yaml
version: '3.8'

services:
  app:
    image: ${SERVICE_IMAGE_NAME}:${SERVICE_IMAGE_TAG}
    restart: unless-stopped
    environment:
      - BOT_TOKEN=${BOT_TOKEN}
```

---

### Шаг 2. Создайте токен доступа (1 раз на проект)

Для запуска деплоя вашему репозиторию нужен токен с правом вызова пайплайна в `wlgdev/deploy`:

1. В правом верхнем углу GitHub нажмите на свой аватар → **Settings**.
2. В левом меню в самом низу перейдите в **Developer settings**.
3. Выберите **Personal access tokens** → **Fine-grained tokens** и нажмите **Generate new token**.
4. Заполните параметры:
   - **Token name**: `deploy-trigger-<имя-вашего-репозитория>`
   - **Expiration**: `1 year`
   - **Resource owner**: выберите организацию `wlgdev`
   - **Repository access**: выберите **Only select repositories** и отметьте репозиторий **`deploy`**
   - **Permissions**: раскройте **Repository permissions** → найдите строку **Actions** → выберите **Read and write**
5. Нажмите **Generate token** и скопируйте сгенерированный токен (начинается на `github_pat_...`).

---

### Шаг 3. Сохраните токен в своём репозитории

1. Откройте свой проект на GitHub.
2. Перейдите во вкладку **Settings** → слева **Secrets and variables** → **Actions**.
3. Нажмите кнопку **New repository secret**.
4. Введите имя: `DEPLOY_TRIGGER_PAT`
5. В поле **Secret** вставьте скопированный токен и нажмите **Add secret**.

---

### Шаг 4. Настройте пайплайны деплоя

#### Dev-окружение: деплой при пуше в основную ветку

Создайте файл `.github/workflows/deploy-dev.yml` в своём репозитории:

```yaml
name: deploy-dev

on:
  push:
    branches: [main, master]
  workflow_dispatch:

permissions:
  contents: read
  packages: write

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/metadata-action@v5
        id: meta
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=sha
            type=raw,value=dev

      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - uses: wlgdev/deploy/.github/actions/deploy@main
        with:
          pat: ${{ secrets.DEPLOY_TRIGGER_PAT }}
          is_dev: 'true'
```

При каждом пуше в `main` или `master` сервис будет автоматически развёрнут в изолированном dev-стеке `/data/apps/<имя-проекта>-dev`.

---

#### Prod-окружение: деплой при публикации релиза

Создайте файл `.github/workflows/deploy-prod.yml` в своём репозитории:

```yaml
name: deploy-prod

on:
  release:
    types: [published]

permissions:
  contents: read
  packages: write

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/metadata-action@v5
        id: meta
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=ref,event=release
            type=sha

      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - uses: wlgdev/deploy/.github/actions/deploy@main
        with:
          pat: ${{ secrets.DEPLOY_TRIGGER_PAT }}
          is_dev: 'false'
```

При публикации релиза сервис развернётся в прод-стеке `/data/apps/<имя-проекта>`.

---

### Шаг 5. Передача переменных и секретов

Если приложению требуются токены или параметры конфигурации, передайте их в параметре `env` строками `КЛЮЧ=ЗНАЧЕНИЕ`:

```yaml
      - uses: wlgdev/deploy/.github/actions/deploy@main
        with:
          pat: ${{ secrets.DEPLOY_TRIGGER_PAT }}
          is_dev: 'true'
          env: |
            BOT_TOKEN=${{ secrets.BOT_TOKEN }}
            DATABASE_URL=${{ secrets.DATABASE_URL }}
            LOG_LEVEL=info
```

*Переменные передаются в процесс запуска и не сохраняются в виде файлов на диске сервера.*

---

### Шаг 6. Деплой веб-сервисов на внешний поддомен (Traefik)

Если вашему приложению нужен доступ из интернета по HTTPS (веб-сайт, API, вебхук):
1. Добавьте параметр `target`:
   ```yaml
         - uses: wlgdev/deploy/.github/actions/deploy@main
           with:
             pat: ${{ secrets.DEPLOY_TRIGGER_PAT }}
             is_dev: 'true'
             target: 'mybot:app:8080'
   ```
2. Формат параметра: `ПОДДОМЕН:СЕРВИС:ПОРТ`
   - Для **Dev-стека** (`is_dev: 'true'`): адрес `https://<поддомен>.dev.wlg.tv`
   - Для **Prod-стека** (`is_dev: 'false'`): адрес `https://<поддомен>.wlg.tv`
   - Для нескольких сервисов укажите строки построчно:
     ```yaml
             target: |
               api:backend:3000
               app:frontend:80
     ```
3. SSL-сертификаты выпускаются автоматически через Let's Encrypt.
4. Если параметр `target` **не указан**, проект деплоится в стандартном headless-режиме (без проксирования и внешних сетей).

---

## Мониторинг и просмотр логов

- **Зелёный статус** шага в GitHub Actions означает успешный запуск контейнеров на сервере.
- **Красный статус**: если сборка или запуск упали, в лог шага выводится прямая ссылка на запуск в `wlgdev/deploy`, где можно посмотреть подробный вывод `docker compose`.

---

## Откат на предыдущую версию (Rollback)

Если после деплоя возникла проблема:
1. Откройте репозиторий `wlgdev/deploy` → вкладка **Actions**.
2. В левой колонке выберите workflow **deploy**.
3. Нажмите **Run workflow**:
   - В поле **repo** укажите `wlgdev/<имя-вашего-проекта>`.
   - В поле **sha** укажите 40-значный хэш стабильного коммита.
   - В поле **is_dev** выберите целевое окружение (`false` для прода, `true` для дева).
4. Нажмите кнопку запуска.

---

## Параметры экшена `wlgdev/deploy/.github/actions/deploy`

| Параметр | По умолчанию | Описание |
|---|---|---|
| `pat` | *Обязательный* | Секрет `${{ secrets.DEPLOY_TRIGGER_PAT }}` для авторизации |
| `is_dev` | `'true'` | `'true'` для dev-стека (`<app>-dev`), `'false'` для продакшена (`<app>`) |
| `target` | `''` | `ПОДДОМЕН:СЕРВИС:ПОРТ` для Traefik HTTPS-роутинга (пусто = headless) |
| `docker_compose_path` | `docker-compose.yml` | Путь к файлу compose относительно корня репозитория |
| `env` | `''` | Переменные окружения вида `KEY=VALUE` (построчно) |
| `service_image_name` | `ghcr.io/wlgdev/<repo>` | Кастомный адрес реестра образов (если отличается от стандартного) |
| `service_image_tag` | sha / имя релиза | Кастомный тег образа |
| `central_ref` | `main` | Ветка репозитория `wlgdev/deploy` |

---

## Для администраторов сервера

### Необходимые секреты в `wlgdev/deploy`:
- `DEPLOY_SSH_HOST`, `DEPLOY_SSH_PORT`, `DEPLOY_SSH_USER`, `DEPLOY_SSH_KEY` — реквизиты SSH пользователя `deploy`.
- `ORG_READ_PAT` — Classic PAT с областью `repo` для выкачивания приватных репозиториев организации.
- Переменная `GHCR_USER` — пользователь для GHCR.

### Проверка конфигурации сервера:
```bash
ssh root@HOST 'bash -s' < scripts/check-server.sh
```
