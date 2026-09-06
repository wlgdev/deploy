# Деплой проекта через wlgdev/deploy (v1: headless, без трафика извне)

> Этот файл — для тебя и твоего агента. Деплой = собрать образ, запушить в
> `ghcr.io`, дёрнуть центральный workflow. SSH-ключи и хосты тебе не нужны.

## Требования

1. Репозиторий в `wlgdev`, `docker-compose.yml` в корне (или свой путь).
2. Compose ссылается ТОЛЬКО на собранные образы (никакого `build:` на сервере),
   координаты — через переменные: `image: ${SERVICE_IMAGE_NAME}:${SERVICE_IMAGE_TAG}`.
3. Образы пушатся по конвенции (тогда в deploy-джобе не нужны outputs сборки):
   - push в `master` → тег `dev`: `ghcr.io/wlgdev/<app>:dev`
   - published release `vX.Y.Z` → тег релиза: `ghcr.io/wlgdev/<app>:vX.Y.Z`
4. Секрет `DEPLOY_TRIGGER_PAT` в настройках репо (выдаёт мейнтейнер `wlgdev/deploy`).

## Дев: push в master → стек `<app>-dev`

```yaml
  deploy-dev:
    if: github.ref == 'refs/heads/master'
    runs-on: ubuntu-latest
    steps:
      - run: |
          APP="${REPO#wlgdev/}"
          curl -sf -X POST -H "Authorization: Bearer $PAT" -H 'Accept: application/vnd.github+json' \
            "https://api.github.com/repos/wlgdev/deploy/actions/workflows/deploy.yml/dispatches" \
            -d "$(jq -n --arg repo "$REPO" --arg sha "$SHA" --arg app "$APP" \
              '{ref:"main",inputs:{repo:$repo, sha:$sha, is_dev:"true",
                compose_path:"docker-compose.yml",
                env:(["SERVICE_IMAGE_NAME=ghcr.io/wlgdev/"+$app,
                      "SERVICE_IMAGE_TAG=dev"] | join("\n"))}}')"
        env:
          PAT: ${{ secrets.DEPLOY_TRIGGER_PAT }}
          REPO: ${{ github.repository }}
          SHA: ${{ github.sha }}
```

## Прод: published release → стек `<app>`

Тот же джоб, триггер `on: {release: {types: [published]}}`, `is_dev:"false"`,
`SERVICE_IMAGE_TAG` = имя релиза: добавь `--arg tag "$TAG"` с
`TAG: ${{ github.event.release.tag_name }}` в env. Дев-стек не трогается.
Порядок не важен, но обычно добавляют `needs: [docker]`, чтобы диспатч уходил
после успешного пуша образа.

## Параметры

| Input | Пример |
|---|---|
| `repo` | всегда `${{ github.repository }}` |
| `sha` | всегда `${{ github.sha }}` (релиз: тоже sha коммита релиза) |
| `is_dev` | `true` → `/opt/apps/<app>-dev`, `false` → `/opt/apps/<app>` |
| `env` | `K=V` построчно → пишется в `.env` (chmod 600) рядом с compose |
| `compose_path` | если compose не в корне |

## Правила

- Данные живут в volumes внутри `/opt/apps/<app>` — переживают редеплои.
- Откат = ручной Run workflow в `wlgdev/deploy` со старым `sha`
  (образ с этим SHA должен существовать).
- Упал деплой — лог run'а в `wlgdev/deploy` → Actions; твой репо там только inputs.
