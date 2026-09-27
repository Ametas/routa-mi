# RoutaMi — базовая линия (разведка SlClash v2.2.3)

Дата разведки: 2026-09-27. Все SHA проверены клонированием исходных репозиториев.

## 1. Проверка исходных фактов

| Факт из задачи | Результат | Детали |
|---|---|---|
| Источник `songzhengpei/Slclash`, тег v2.2.3 = d3fe5c8 | ✅ подтверждён | Тег аннотированный (объект `93da6f3`), указывает на `d3fe5c8b8195e8a6bfa92d10ecdd304f6b56f028` «docs: add v2.2.3 app changelog». `main` == v2.2.3, ветка `beta` не опережает `main` (0 коммитов). В истории 879 коммитов. |
| Ответвление от FlClash на v0.8.93, merge-base ac2f6b9 | ✅ подтверждён | `git merge-base slclash/main flclash/main` = `ac2f6b919ec1…` («Update changelog», chen08209), это `v0.8.93-1-gac2f6b91` (v0.8.93 + 1 коммит). После развилки: SlClash +675 коммитов, FlClash +29 (до `c7be702`, 2026-09-17). |
| Лицензия GPL-3.0 | ✅ | `LICENSE` — GNU GPL v3, 29 June 2007. |
| Submodule `core/Clash.Meta` → `songzhengpei/Clash.Meta`, ветка FlClash, коммит ac017cd = mihomo v1.19.30 | ✅ | `.gitmodules`: url `https://github.com/songzhengpei/Clash.Meta.git`, `branch = FlClash`. Gitlink `ac017cdd246ce8bd547653d927e7bf77d7ee73d5` — это ровно тег `v1.19.30` в `MetaCubeX/mihomo` (своих коммитов поверх нет). |
| Патч `core/patches/mihomo/proxy-only-traffic.patch` | ✅ | 363 строки, затрагивает `adapter/outbound/base.go`, `constant/adapters.go`, `tunnel/statistic/{manager.go,tracker.go}` и добавляет `tunnel/statistic/manager_proxy_test.go`. |
| Workflows: mihomo-compatibility, mihomo-core-update, slclash-android-beta, slclash-android-release | ✅ | Все четыре есть, подробности ниже. |
| **Есть `plugins/rust_api` (cargokit), сборке нужен Rust** | ❌ **не подтверждается** | В v2.2.3 `plugins/` содержит только `setup` и `wifi_ssid`. `plugins/rust_api` (а также `proxy`, `tray_manager`, `window_ext`, `flutter_distributor`) существовал в FlClash и был **удалён** в SlClash коммитом `0850b43d` «feat: prepare Android-only SlClash release» (2026-06-11). Упоминаний cargo/cargokit в дереве нет. `AGENTS.md` SlClash прямо запрещает возвращать «Rust IPC helpers». **Rust для сборки не нужен.** |

## 2. Структура репозитория SlClash v2.2.3

- `lib/` — Flutter-приложение, Dart-пакет `fl_clash` (импорты `package:fl_clash/...`).
- `android/` — модули `app`, `core`, `service`, `common`. Kotlin-пакеты `com.follow.clash.*` (наследие FlClash); `namespace = "com.slclash.app"`, `applicationId = "com.slclash.app"`.
- `core/` — Go-обёртка (cgo-мост в `libclash.so`), `go.mod` модуль `core`, `replace github.com/metacubex/mihomo => ./Clash.Meta`.
- `core/patches/mihomo/` — патчи поверх mihomo (сейчас один файл).
- `plugins/setup/` — локальный Flutter-плагин + `buildkit` (Dart build_tool, Gradle-хук сборки Go-ядра).
- `plugins/wifi_ssid/` — локальный плагин.
- `scripts/` — `mihomo-core-relationship.sh` (EXACT/AHEAD/BEHIND/DIVERGED по предкам, не по датам) и контрактный тест к нему.
- `test/` — Flutter-тесты (17 каталогов), `tools/perf/` — perf-харнесс на Python (ссылается на `com.slclash.app*`).
- `docs/` — заметки SlClash (phase4, mihomo, design), `AGENTS.md` — инструкции для агентов SlClash (Windows-пути, ветка `beta`).

Только Android, только ABI `arm64-v8a`.

## 3. Как собирается ядро и накладываются патчи

1. Gradle-скрипт `plugins/setup/buildkit/gradle/plugin.gradle` добавляет задачу перед `mergeNativeLibs`, которая запускает `plugins/setup/buildkit/run_build_tool.sh android --arch arm64` (нужна переменная `ANDROID_NDK`). Пропуск — `-PslclashSkipGoCoreBuild=true`.
2. `run_build_tool.sh` компилирует Dart build_tool в `build/setup_build_tool/` и вызывает его.
3. `go_builder.dart` перед `go build` вызывает `MihomoPatcher.apply()`:
   - если `git apply --reverse --check` успешен — патч уже наложен, ничего не делает;
   - иначе `git apply --check`, при несовместимости — ошибка сборки;
   - затем `git apply --whitespace=nowarn` внутри `core/Clash.Meta`.
   - **Путь к патчу зашит**: `core/patches/mihomo/proxy-only-traffic.patch` (обрабатывается ровно один файл).
4. Отдельная команда `dart run bin/build_tool.dart --root-dir … patch-mihomo` накладывает патч без сборки (используется в CI для тестов).
5. Результат: `libclash/android/arm64-v8a/libclash.so` + заголовки, копия в `android/core/src/main/jniLibs/arm64-v8a/`.

### Проверка патча на новом mihomo

Последний стабильный релиз `MetaCubeX/mihomo` — **v1.19.31** (`ab405bad`, 2026-09-14; 51 коммит после v1.19.30; старших `vX.Y.Z` тегов нет).

```
git -C mihomo checkout v1.19.31
git apply --check -v proxy-only-traffic.patch
  Checking patch adapter/outbound/base.go...
  Checking patch constant/adapters.go...   Hunk #1 succeeded at 70 (offset 2 lines).
  Checking patch tunnel/statistic/manager.go...
  Checking patch tunnel/statistic/manager_proxy_test.go...
  Checking patch tunnel/statistic/tracker.go...
```

Патч накладывается **без адаптации** (только смещение на 2 строки в `constant/adapters.go`: между v1.19.30 и v1.19.31 в этом файле добавлены 3 строки, остальные затронутые файлы не менялись). Сборку и `go test ./tunnel/statistic` на пропатченном v1.19.31 ещё предстоит прогнать.

## 4. Версии инструментов (из workflows и Gradle SlClash)

| Инструмент | Версия | Где зафиксировано |
|---|---|---|
| Flutter | 3.41.9 stable (Dart 3.11.5) | все workflows, `subosito/flutter-action@v2` |
| Dart SDK constraint | `>=3.8.0 <4.0.0` | `pubspec.yaml` |
| Go | 1.24.0 | workflows, `actions/setup-go@v5` (`core/go.mod`: `go 1.21`, mihomo: `go 1.20`) |
| JDK | Temurin 21 (компиляция под Java 17) | workflows, `android/app/build.gradle.kts` |
| Android NDK | r28c = 28.2.13676358 | workflows (`nttld/setup-ndk@v1`), `android/gradle/libs.versions.toml` |
| compileSdk / targetSdk | 36 / 36 | `libs.versions.toml` |
| minSdk | `flutter.minSdkVersion` (toml указывает 23) | `app/build.gradle.kts` |
| AGP / Kotlin | 8.12.2 / 2.2.10 | `android/settings.gradle.kts` |
| Gradle | 8.13 | `gradle-wrapper.properties` |
| Rust | **не требуется** | см. §1 |

## 5. Workflows SlClash

| Файл | Триггер | Что делает | Риск для нас |
|---|---|---|---|
| `mihomo-compatibility.yml` | `pull_request` | при изменении `core/**` и др.: patch-mihomo, subset flutter-тестов, `go test ./providerbridge ./configfixture` | безопасен, но дублирует новый CI |
| `mihomo-core-update.yml` | `schedule` (пн 03:20 UTC) + dispatch | checkout **`beta`**, сверка с релизом MetaCubeX, коммит в ветку `codex/mihomo-core-<tag>`, push, **draft PR в `beta`**; тексты на китайском | после появления `main` будет запускаться по расписанию; у нас нет `beta` → упадёт на checkout |
| `slclash-android-beta.yml` | dispatch | создаёт тег `YYYY.MM.DD-beta`, требует секрет `KEYSTORE`, публикует prerelease «SlClash» | публикация от имени SlClash |
| `slclash-android-release.yml` | push тегов `[0-9]*`, `v[0-9]*` + dispatch | коммитит changelog в `main`, создаёт тег, подписывает (`KEYSTORE`, `KEY_ALIAS`, `STORE_PASSWORD`, `KEY_PASSWORD` → `android/local.properties`), проверяет `packageName == com.slclash.app`, публикует Release «SlClash» | **сработает на push любого старого тега SlClash** |

Полезное, что стоит сохранить: схема подписи через `android/local.properties` + `android/app/keystore.jks` (Gradle при этом не трогаем), кэш собранного `libclash.so` по хэшу исходников, проверка APK через `aapt2`, `versionCode` = unix-время (влезает в лимит 2 100 000 000 до 2036 г.), метаданные ядра через `--dart-define` (`MIHOMO_VERSION`, `CORE_SHA256`, …).

Замечание: root-пакет `core/` — Android/cgo-мост; SlClash сознательно гоняет на Linux только `go test ./providerbridge ./configfixture` и `go test ./tunnel/statistic` в mihomo. Будет ли работать `go test ./...` в `core/` на хосте — проверю при реализации.

## 6. Где «зашит» бренд SlClash (для ребрендинга)

- `android/app/build.gradle.kts`: `applicationId`, метки debug/profile-сборок («SlClash Debug», «SlClash Profile»). `namespace` **оставляем** `com.slclash.app` — он не виден пользователю, а его смена ломает перенос коммитов (R/BuildConfig).
- `android/app/src/main/AndroidManifest.xml`: `android:label="SlClash"` (приложение и активити). Все action/authority/permission строятся через `${applicationId}` — смена applicationId их корректно переименует.
- `lib/common/constant.dart`:
  - `appName = 'SlClash'` — заголовок MaterialApp, User-Agent (`SlClash/vX clash-verge Platform/android` — `clash-verge` остаётся, подписки не сломаются), имя TUN-устройства по умолчанию, имена файлов бэкапа/логов;
  - `packageName = 'com.slclash.app'` — константа, похоже, не используется;
  - **`repository = 'songzhengpei/Slclash'` — встроенный автоапдейтер** (`lib/common/update.dart`) проверяет releases этого репозитория и предлагает скачать/установить их APK. Без смены RoutaMi будет предлагать пользователю APK SlClash.
- `lib/providers/action.dart:529` — имя по умолчанию `SlClash-update.apk` (временный файл).
- ARB-строки (`arb/intl_*.arb` → генерируемые `lib/l10n/`): «Start SlClash when…», «Allow SlClash to install unknown apps…», aboutDescription, записи changelog.
- Тестовые фикстуры и `tools/perf` — оставить как есть.

Отдельно: апдейтер скачивает APK сначала через сторонний зеркальный прокси `gh-proxy.com`, сверяя SHA-256 из GitHub API — кандидат в бэклог.
