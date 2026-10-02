# CLAUDE.md — правила проекта RoutaMi

RoutaMi — Android-клиент (arm64-v8a) на ядре mihomo, жёсткий форк SlClash
(← FlClash). См. `README.md`, `UPSTREAM.md`, `docs/NOTES-baseline.md`.

`AGENTS.md` унаследован от SlClash и описывает **их** окружение (Windows-пути,
ветка `beta`, пакет `com.slclash.app`). Где он противоречит этому файлу,
действует этот файл. Полезное из него: архитектура сборки ядра, поведение
медиа-проверок, запрет редактировать сгенерированные файлы.

## Правила

1. **Новый код — в новых файлах.** Файлы апстрима (особенно крупные:
   `lib/providers/action.dart`, `lib/state.dart`, `lib/application.dart`,
   `lib/common/constant.dart`, `lib/models/*`, `android/**/build.gradle.kts`)
   меняем минимально: точка подключения в одну-две строки, логика — в своём
   файле. Иначе ломается `git cherry-pick` из апстрима.
   Это касается функциональной логики. **Интерфейс из SlClash не
   переносим** — у RoutaMi свой дизайн, поэтому экраны (`lib/views`,
   `lib/pages`), виджеты (`lib/widgets`) и тему (`lib/theme`) меняем
   свободно. Правила дизайн-системы — `docs/design/design-system-audit.md`.
2. **Не переименовывать** Dart-пакет `fl_clash`, пути импортов, имена файлов,
   Kotlin-пакеты `com.follow.clash.*`, `namespace` Android (`com.slclash.app`),
   Gradle-свойства `slclash*`. Бренд меняется только в видимых строках.
3. **mihomo меняем только патчами** в `core/patches/mihomo/*.patch`
   (накладываются по алфавиту, каждый — идемпотентно). Никаких коммитов
   внутрь `core/Clash.Meta`; submodule всегда указывает на официальный тег
   MetaCubeX. Обновляет ядро `.github/workflows/mihomo-core-update.yml`.
4. **Conventional Commits**: `feat:`, `fix:`, `chore:`, `docs:`, `ci:`,
   `test:`, `refactor:`, `build:`; область по желанию (`fix(core): …`).
   Перенос из апстрима — `git cherry-pick -x`.
   **Коротко:** коммит — заголовок и при необходимости 1–3 строки «зачем»;
   описание PR — 3–5 пунктов «что изменилось» и одна строка о проверке.
   Не пересказывать diff, не перечислять файлы и тесты поимённо.
5. **После любого переноса из апстрима обновить `UPSTREAM.md`** (таблица
   решений + «последний просмотренный коммит») в том же PR.
6. Не редактировать сгенерированное (`lib/**/generated/`, `lib/l10n/`):
   правим исходники (`arb/*.arb`, модели) и перегенерируем.
7. Секреты и ключи никогда не коммитить (`*.jks`, `*.keystore`,
   `android/local.properties` в `.gitignore`).
8. Изменения поведения сопровождать тестами.
9. **Дизайн-токены.** Отступы — `SurgeSpace`, иконки — `SurgeIconSize`,
   радиусы — `surge.radii`, цвета — `SurgeTheme`/`colorScheme`
   (вне темы — роли `SurgePalette`, статусы задержки — `surge.latencyColor`),
   прозрачность — шкала `SurgeAlpha` или семантика `SurgeOpacity`,
   тени — уровни `SurgeShadows`, анимации — роли `SurgeMotion` на шкале
   `SurgeDuration` (таймауты и интервалы логики — не токены), масштаб под экран — `UiScale` (`lib/theme/ui_scale.dart`),
   Material-темы компонентов — `lib/theme/surge_theme_data.dart` (не
   задавайте голым виджетам то, что уже даёт тема).
   Новые литералы ловит `test/design/design_token_ratchet_test.dart`;
   убрали литералы — обновите базовую линию:
   `UPDATE_DESIGN_BASELINE=1 flutter test test/design/design_token_ratchet_test.dart`.

## Окружение

Облачная сессия: `bash scripts/cloud-setup.sh`, затем
`source /opt/routami-tools/env.sh`. Версии: Flutter 3.41.9, Go 1.24.13,
JDK 21, NDK r28c (28.2.13676358), Android SDK 36. Rust не нужен.
Версии синхронны с `.github/actions/setup-toolchain/action.yml`.

## Команды

```bash
flutter pub get                       # pubspec.lock не коммитить, если его изменил только pub get
bash plugins/setup/buildkit/run_build_tool.sh patch-mihomo
flutter analyze --no-fatal-infos
flutter test                          # ДО go test: генерирует build/mihomo-runtime-fixtures
(cd core && CGO_ENABLED=0 go test -tags=with_gvisor,cmfa ./...)
(cd core/Clash.Meta && go test ./tunnel/statistic)

# debug APK (icu.routaterm.routami.dev)
bash plugins/setup/buildkit/run_build_tool.sh android --arch arm64
flutter build apk --debug --target-platform android-arm64 \
  --android-project-arg=slclashSkipGoCoreBuild=true
```

`dart run build_runner build --delete-conflicting-outputs` — только после
изменения моделей / Riverpod-провайдеров / схемы Drift.

## CI

- `ci.yml` — каждый push в любую ветку: тесты + debug APK (артефакт).
- `release.yml` — тег `vX.Y.Z` на коммите из `main` или ручной запуск на
  `main` с полем tag (тег создаётся после сборки): CI, подпись, GitHub Release.
- `mihomo-core-update.yml` — еженедельно: PR с новым релизом MetaCubeX.

Источник истины — CI. Подробности релиза: `docs/RELEASE.md`. Бэклог:
`docs/BACKLOG.md`.
