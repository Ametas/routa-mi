# Журнал апстрима

RoutaMi — жёсткий форк [SlClash](https://github.com/songzhengpei/Slclash),
который сам ответвился от [FlClash](https://github.com/chen08209/FlClash).
Мы **не сливаем** апстримы: изменения переносятся точечно через
`git cherry-pick -x` и фиксируются в таблице ниже.

## База

| | Значение |
|---|---|
| Апстрим | `songzhengpei/Slclash` (remote `slclash`) |
| Базовый тег | `v2.2.3` |
| Базовый коммит | `d3fe5c8b8195e8a6bfa92d10ecdd304f6b56f028` |
| **Последний просмотренный коммит SlClash** | `d3fe5c8b8195e8a6bfa92d10ecdd304f6b56f028` (`main` и `beta`, 2026-09-27) |
| Прародитель | `chen08209/FlClash` (remote `flclash`, только для справки) |
| Точка ответвления SlClash от FlClash | `ac2f6b919ec1ad395b61b4bb1e714a39c750babe` (v0.8.93 + 1) |

## Ядро

| | Значение |
|---|---|
| Submodule | `core/Clash.Meta` → `https://github.com/MetaCubeX/mihomo.git` |
| Версия | `v1.19.31` (`ab405bad5beeeac8b003bb01f60f134f6df54471`) |
| У SlClash было | `songzhengpei/Clash.Meta` ветка `FlClash`, `ac017cd` = mihomo `v1.19.30` |
| Патчи | `core/patches/mihomo/*.patch` (накладываются по алфавиту) |

История ядра:

| Дата | Версия | Коммит | Изменения патчей / фикстур |
|---|---|---|---|
| 2026-09-27 | v1.19.31 | `ab405bad` | `proxy-only-traffic.patch` наложился без правок (смещение 2 строки в `constant/adapters.go`). В `RawTun` появилось непубличное поле `processors-per-channel` (по умолчанию 1, апстрим `92433dba`) — добавлено в `test/fixtures/mihomo/e2e/*/rawconfig.json`. |

## Решения по коммитам SlClash

Статусы: **перенесён** (cherry-pick, указать наш SHA), **пропущен** (не нужен
или противоречит целям RoutaMi), **отложен** (нужен, но позже).

| Коммит SlClash | Дата | Суть | Статус | Наш коммит | Причина / комментарий |
|---|---|---|---|---|---|
| — | — | Коммитов после `d3fe5c8` пока нет | — | — | — |

### Локальные отклонения от SlClash (не из апстрима)

Правки файлов апстрима, которые могут конфликтовать при переносе:

| Файл | Что изменено | Почему |
|---|---|---|
| `android/app/build.gradle.kts` | `applicationId`, метки debug/profile | ребрендинг |
| `android/app/src/main/AndroidManifest.xml` | `android:label` | ребрендинг |
| `lib/common/constant.dart` | `appName`, `packageName`, `repository` | ребрендинг, апдейтер смотрит в наш репозиторий |
| `plugins/setup/buildkit/build_tool/lib/src/mihomo_patcher.dart` | накладывает все `*.patch`, а не один файл | механизм патчей ядра |
| `.gitmodules`, `core/Clash.Meta`, `core/go.mod`, `core/go.sum` | ядро с MetaCubeX, v1.19.31 | официальное ядро |
| `test/fixtures/mihomo/e2e/*/rawconfig.json` | `processors-per-channel` | контракт RawConfig v1.19.31 |
| `test/widgets/changelog_dialog_test.dart` | проверяет первую запись changelog вместо `v2.0.7` | тест апстрима устарел (падает и в SlClash v2.2.3) |
| `test/theme/typography/type_scale_test.dart` | `dashboardLatencyValue` height `0` | тест апстрима не обновлён после SlClash `027f90f5` |
| `.github/workflows/*` | workflows SlClash удалены, свои: `ci.yml`, `release.yml`, `mihomo-core-update.yml` | CI RoutaMi |
| `README.md`, `README_EN.md` | README переписан, `README_EN.md` (SlClash, ссылки на их загрузки) удалён | описание форка |
| `lib/models/config.dart`, `lib/models/core.dart`, `lib/models/state.dart`, `lib/common/task.dart`, `lib/state.dart`, `lib/providers/{action,state}.dart`, `lib/common/http.dart`, `core/common.go`, `core/constant.go` | точки подключения авторизации локального порта (`AuthenticationProps`, `authentication` в `UpdateParams`/`MakeRealProfileState`, патч профиля, учётные данные в прокси-строках, Go `applyAuthentication`) | 🔴 бэклога; логика в новых файлах `lib/common/local_proxy_auth.dart`, `lib/services/mihomo_config/authentication_patch.dart`, `core/authentication.go`, `lib/views/config/local_proxy_auth_items.dart` |
| `lib/models/config.dart`, `lib/models/state.dart`, `lib/common/task.dart`, `lib/providers/action.dart`, `lib/views/config/general.dart` | точки подключения локального plain VLESS-входа (`LocalVlessProps` в `NetworkProps`, `localVlessListener` в `MakeRealProfileState`, слушатель `routami-vless` в профиле, его порт в проверке конфликтов) | свой вход для клиентов на устройстве; логика в новых файлах `lib/common/local_vless.dart`, `lib/views/config/local_vless_items.dart`, патч в `authentication_patch.dart` |
| `lib/common/request.dart` | апдейтер сравнивает версии через `isNewerAppVersion` | `utils.compareVersions` падает на `0.1.0-rc.1`; логика в `lib/common/app_version.dart` |
| `arb/*.arb`, `android/**/*.kt` (уведомления, VPN-сессия, `FilesProvider`), `lib/common/app_changelog.dart` | видимые строки «SlClash/FlClash» → RoutaMi, свой changelog с v0.1.0 | ребрендинг до релиза |

### Перенесено из FlClash вручную

FlClash (`chen08209/FlClash`) — прародитель, не апстрим: его код ушёл далеко
от SlClash, поэтому идеи переносим вручную, а не `cherry-pick`.

| Что | Откуда в FlClash | Отличия RoutaMi |
|---|---|---|
| Авторизация локального порта: модель, Go `applyAuthentication` с очисткой `skip-auth-prefixes`, раскладка «Входящие» → «Аутентификация» в основных настройках, подпись системного прокси | `c6eaa0a` (core), `aaf934c` (app), состояние на `c7be702` | включена по умолчанию; логин 16 и пароль 32 символа из CSPRNG (у FlClash выключена, 8/16); показать/скопировать/перегенерировать; подтверждение при выключении; учётные данные дозаполняются после сброса и восстановления старого бэкапа |

## Как проводить ревизию апстрима

```bash
git fetch slclash --tags
LAST=d3fe5c8b8195e8a6bfa92d10ecdd304f6b56f028   # из таблицы «База»
git log --oneline --no-merges "$LAST"..slclash/main
git log --oneline --no-merges "$LAST"..slclash/beta   # SlClash ведёт разработку в beta
```

Для каждого коммита:

1. Посмотреть `git show <sha>`. Решить: перенести, пропустить или отложить.
   Обычно **пропускаем**: коммиты changelog/релизов SlClash, их workflows,
   правки `AGENTS.md`/доков под их окружение, ребрендинг SlClash и **любые
   интерфейсные изменения** (виджеты, экраны, тема, типографика) — переносим
   только функциональные. Смешанный коммит переносим частично: логику —
   вручную, с указанием источника в сообщении коммита.
2. Перенос — в отдельной ветке:
   ```bash
   git switch -c port/slclash-<short-sha> origin/main
   git cherry-pick -x <sha>          # -x оставляет ссылку на исходный коммит
   ```
   Конфликты в файлах из таблицы «Локальные отклонения» решать в пользу
   нашей стороны для ребрендинга. Коммиты, меняющие `core/Clash.Meta`,
   **не** переносить как есть — ядро обновляет `mihomo-core-update.yml`.
3. Прогнать `flutter analyze`, `flutter test`, Go-тесты (см. `CLAUDE.md`).
4. Добавить строку в таблицу решений (в том числе для пропущенных) и
   обновить «Последний просмотренный коммит SlClash» — в том же PR.

FlClash (`git fetch flclash`) смотрим только для справки: история
разошлась на ~700 коммитов, прямой cherry-pick оттуда почти всегда
конфликтует — переносить вручную с указанием источника в сообщении коммита.
