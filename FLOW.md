# FLOW — полный путь деплоя (v1, headless)

## Пути на сервере

- Прод: `/opt/apps/<app>/` (`docker-compose.yml` + `.env`), стек `up -d`.
- Дев: `/opt/apps/<app>-dev/` — то же отдельно. Окружение выбирает юзер
  своим триггером через `is_dev`. Старого `/data/compose` не касаемся.

## Снепшот: push в master → стек `<app>-dev`

1. Workflow юзера: сборка → push `ghcr.io/wlgdev/<app>:dev`.
2. Джоб `deploy-dev` шлёт диспатч (`repo`, `sha`, `is_dev=true`,
   `env=SERVICE_IMAGE_NAME=…/SERVICE_IMAGE_TAG=dev`).
3. Центральный run: Validate (org-gate `wlgdev/*`, имя `[a-z0-9-]`, sha hex-40,
   `compose_path` без `..`) → checkout `repo@sha` → `mkdir /opt/apps/<app>-dev`
   → `scp` compose как `.new` → запись `.env` (600) → `mv` → `pull` →
   `up -d --remove-orphans` → `prune` → `ps` в лог.
4. Прод-стек не тронут.

## Релиз: published release → стек `<app>`

То же с `is_dev=false`, тег образа = имя релиза.

## Ручной редеплой/откат

Run workflow в `wlgdev/deploy` с нужным `sha` (образ должен существовать).

## Ошибки и ротация

- Невалидные inputs — падение на Validate, сервер не тронут.
- Обрыв `scp` — старый compose продолжает работать (подмена через `.new`+`mv`);
  упавший `pull` — контейнеры продолжают крутиться на старом образе до
  следующего успешного деплоя.
- Два диспатча на один стек сериализуются (`concurrency`).
- Ротация SSH: новый ключ → append паблика → секрет → деплой пилота → убрать
  старый. Ротация PAT: перегенерить → секрет → редеплой. Ротация GHCR-auth:
  `docker login` под `deploy` заново.
