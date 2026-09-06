# wlgdev/deploy — централизованный деплой v1

Деплоит headless-приложения организации (боты, воркеры — всё, что **ничего
не выставляет наружу**). Traefik/поддомены `*.wlg.tv` — не v1, см. `PLAN.md`.
Старый деплой через `template-repository` не трогаем: свой юзер, свой ключ,
своя папка (`/opt/apps`).

Как пользуется проект — см. `AGENTS.md`. Устройство — `ARCHITECTURE.md`,
пошаговые пути — `FLOW.md`, внедрение — `PLAN.md`.

## Секреты центрального репо

| Secret | Что это |
|---|---|
| `DEPLOY_SSH_KEY` | новый ed25519 без пароля, пара юзера `deploy` (старые ключи не используем) |
| `DEPLOY_SSH_HOST` | хост прод-сервера |
| `DEPLOY_SSH_USER` | `deploy` |
| `DEPLOY_SSH_PORT` | `22` (можно не задавать) |
| `ORG_READ_PAT` | classic PAT со скоупом `repo` (checkout проектов + `docker login ghcr.io` на сервере) |

| Variable | Что это |
|---|---|
| `GHCR_USER` | логин владельца `ORG_READ_PAT` (для `docker login`) |

В каждом проекте — один секрет `DEPLOY_TRIGGER_PAT` (fine-grained, только репо
`wlgdev/deploy`, `Actions: Read and write`; если диспатч даст 403 — добавить
`Contents: Read` и сообщить сюда).

## Ранбук мейнтейнера

- Новый проект: выдать `DEPLOY_TRIGGER_PAT`, указать на `AGENTS.md`. Всё.
- Ручной редеплой/откат: Actions → deploy → Run workflow (нужен `sha`,
  образ с этим SHA должен быть в `ghcr.io`).
- Ротация SSH: новый ключ → append паблика → обновить секрет → деплой пилота →
  убрать старый паблик. Ротация PAT: перегенерить → обновить секрет → редеплой.
- Сервер: сверка `ssh root@HOST 'bash -s' < scripts/check-server.sh`.
