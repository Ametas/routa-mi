# CI RoutaMi: токен бота обновления ядра и защита `main`

## Зачем боту отдельный токен

`mihomo-core-update.yml` пушит ветку `bot/mihomo-core-<tag>` и открывает PR.
Push и PR, сделанные через встроенный `GITHUB_TOKEN`, **не запускают другие
workflows** (защита GitHub от рекурсии). Значит на ветке бота не будет
push-запуска `ci.yml`, обязательные проверки «Tests (flutter + go)» и
«Debug APK (arm64-v8a)» не появятся, и при защите `main` такой PR нельзя
смёрджить.

Workflow выбирает токен сам, в таком порядке:

1. **GitHub App** — если задана переменная `CORE_UPDATE_APP_ID` (и секрет
   `CORE_UPDATE_APP_PRIVATE_KEY`). Токен выпускается на каждый запуск через
   `actions/create-github-app-token` и живёт 1 час.
2. **Fine-grained PAT** — секрет `CORE_UPDATE_TOKEN`.
3. `GITHUB_TOKEN` — запасной вариант: всё работает, но CI на PR бота
   придётся запускать вручную (Actions → CI → Run workflow → ветка бота);
   workflow пишет об этом предупреждение и в тело PR.

## Рекомендация: GitHub App

| | GitHub App | Fine-grained PAT |
|---|---|---|
| Автор PR и коммитов | `<app>[bot]` | вы |
| Можно одобрить PR бота самому | **да** | **нет** — GitHub не даёт одобрить свой PR; при правиле «Require approvals» PR придётся мёрджить в обход |
| Срок действия | ключ бессрочный, токены по 1 часу | до 1 года, потом перевыпуск |
| Привязка к личному аккаунту | нет | да (утечка = действия от вашего имени) |
| Настройка | ~5 минут | ~2 минуты |

### Вариант A. GitHub App (рекомендуется)

1. GitHub → Settings (личные) → Developer settings → GitHub Apps →
   **New GitHub App**.
   - Name: например `routami-core-bot` (должно быть уникальным на GitHub).
   - Homepage URL: `https://github.com/Ametas/routa-mi`.
   - Webhook: снять галочку **Active**.
   - Repository permissions:
     - **Contents: Read and write** (push ветки бота);
     - **Pull requests: Read and write** (создание/обновление PR);
     - Metadata: Read-only (выставится само).
     - Больше ничего не нужно (в частности, не нужны Workflows и Actions:
       бот не меняет `.github/workflows/`).
   - Where can this GitHub App be installed: **Only on this account**.
2. После создания: запишите **App ID** (на странице приложения).
3. Там же → Private keys → **Generate a private key** — скачается `.pem`.
4. Install App → установить на аккаунт → **Only select repositories** →
   `Ametas/routa-mi`.
5. В репозитории → Settings → Secrets and variables → Actions:
   - вкладка **Variables** → `CORE_UPDATE_APP_ID` = App ID;
   - вкладка **Secrets** → `CORE_UPDATE_APP_PRIVATE_KEY` = всё содержимое
     `.pem` (включая строки `-----BEGIN/END … KEY-----`).
   ```bash
   gh variable set CORE_UPDATE_APP_ID -R Ametas/routa-mi --body 123456
   gh secret set CORE_UPDATE_APP_PRIVATE_KEY -R Ametas/routa-mi < routami-core-bot.*.private-key.pem
   ```
6. Удалите `.pem` с диска (или положите в менеджер паролей). Если ключ
   утёк — удалите его на странице приложения и сгенерируйте новый.

### Вариант B. Fine-grained PAT

1. GitHub → Settings → Developer settings → Personal access tokens →
   **Fine-grained tokens** → Generate new token.
   - Resource owner: `Ametas`; Expiration: до 1 года (поставьте напоминание).
   - Repository access: **Only select repositories** → `Ametas/routa-mi`.
   - Repository permissions: **Contents: Read and write**, **Pull requests:
     Read and write** (Metadata: Read-only добавится само).
2. Секрет `CORE_UPDATE_TOKEN` = токен:
   `gh secret set CORE_UPDATE_TOKEN -R Ametas/routa-mi`.

Если заданы оба варианта, используется App.

### Проверка

Actions → Mihomo Core Update → Run workflow (`dry_run` снят). Пока ядро
актуально, workflow завершится «noop»; в Summary будет строка
`Push token: app` (или `pat`). Когда выйдет новый релиз mihomo, на ветке
бота должен появиться push-запуск CI.

Также нужна настройка Settings → Actions → General → Workflow permissions →
**Allow GitHub Actions to create and approve pull requests** (для
запасного варианта с `GITHUB_TOKEN`).

## Защита `main` (включить после мёрджа PR #1)

Settings → Rules → Rulesets → **New branch ruleset** (или Branches →
Add classic branch protection rule):

- Target: `main` (Include default branch, после переключения ветки по
  умолчанию на `main`).
- **Restrict deletions**, **Block force pushes**.
- **Require a pull request before merging**; «Required approvals» — 0, если
  работаете один (иначе свои PR не смёрджить), 1 — если будут ревьюеры.
- **Require status checks to pass**:
  - `Tests (flutter + go)`
  - `Debug APK (arm64-v8a)`
  - включить «Require branches to be up to date before merging».
  Проверки появятся в списке после первого успешного запуска CI.
- По желанию: **Require linear history** (тогда мёрджить squash/rebase).
- Bypass list: пусто. Бот (App) обходить защиту не должен — его PR
  проходят те же проверки.
