# ARCHITECTURE — централизованный деплой wlgdev (v1)

## Компоненты

```text
wlgdev/deploy                  # центральный репо, держит ВСЕ секреты
├── .github/workflows/deploy.yml   # validate → checkout repo@sha → scp compose → ssh up
└── scripts/check-server.sh        # сверка сервера (только проверки)

проект юзера                   # свой workflow: собрать/запушить образ → curl-диспатч
сервер                         # юзер deploy (группа docker), /opt/apps/<app>[-dev], GHCR-auth
```

v1 — ТОЛЬКО headless (боты, воркеры). Никакого traefik, сетей, `coolify-proxy`,
поддоменов: workflow копирует compose + `.env` и делает
`pull && up -d --remove-orphans && prune`. Публичные веб-сервисы — v2
(см. `PLAN.md`).

## Решения

- **`workflow_dispatch`, а не `workflow_call`**: reusable выполняется в контексте
  вызывающего репо — центральные секреты недоступны. Диспатч выполняется
  центрально. Бонус: ручной Run workflow для редеплоя/отката.
- **Свежие credentials, ноль связи со старым деплоем**: новый юзер `deploy`,
  новый ключ, `/opt/apps` вместо `/data/compose`. Старые секреты не читаем.
- **Один стек на приложение**: `/opt/apps/<app>` (прод) + `/opt/apps/<app>-dev`
  (снепшоты). Атомарная замена compose (`.new` + `mv`), `up` без `down`.
- **Переменные через `.env`-файл**, а не `eval`/`export` по SSH: безопаснее
  кавычек, compose подхватывает сам. Потолок: значения без переводов строк.
- **Без action-обёртки для юзера**: вызов — один `curl`. Добавить, когда
  сниппет начнёт разъезжаться.
- **Classic PAT для чтения** (`repo` + `read:packages`): один токен на checkout
  и `docker login`, без танцев с доступом fine-grained к каждому репо.
  Триггерный PAT — наоборот fine-grained на один репо (least privilege там,
  где раздаём наружу).

## Секреты

Центр: `DEPLOY_SSH_KEY/HOST/USER/PORT`, `ORG_READ_PAT`, variable `GHCR_USER`.
Проект: `DEPLOY_TRIGGER_PAT` (fine-grained, только `wlgdev/deploy`,
`Actions: RW`).
