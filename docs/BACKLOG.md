# Бэклог RoutaMi

Записано, но **не реализовано**. Пункты с пометкой 🔴 — обязательно до
первого публичного релиза.

## 🔴 Ребрендинг видимых строк (обязательно до первого публичного релиза)

Шаг 1 сменил только applicationId, метку приложения, `appName` и имена
артефактов. Остались строки, которые пользователь видит как «SlClash» или
«FlClash». Менять их — правкой исходников с последующей перегенерацией
`lib/l10n/` (`intl_utils`), генерируемые файлы руками не трогать.

ARB-ключи с «SlClash» (`arb/*.arb` → `lib/l10n/`):

| Ключ | `intl_en.arb` | `intl_zh_CN.arb` | Текст (en) |
|---|---|---|---|
| `autoLaunchDesc` | стр. 40 | — (без бренда) | Start SlClash when the device starts |
| `autoRunDesc` | стр. 44 | — (без бренда) | Connect when SlClash opens |
| `aboutDescription` | стр. 553 | стр. 553 | SlClash: Android proxy client based on FlClash & Mihomo core. |
| `allowUnknownAppInstall` | стр. 668 | стр. 668 | Allow SlClash to install unknown apps, then tap Install. |
| `changelog207Item2` | стр. 677 | стр. 677 | Enabled two-way profile backup import between SlClash and Clash Verge Rev. |
| `changelog205Item1` | стр. 680 | стр. 680 | SlClash and Clash Verge Rev profile backups now support two-way import. |
| `changelog204Item2` | стр. 684 | стр. 684 | SlClash exports can import into Clash Verge Rev to overwrite profiles. |

Там же решить:

- `lib/common/app_changelog.dart` — встроенный changelog показывает историю
  релизов SlClash (v2.x); завести свой или скрыть старые записи
  (`changelog2xx*` выше станут не нужны).
- Kotlin, строки «FlClash», видимые в системе:
  `android/common/.../GlobalState.kt` (`NOTIFICATION_CHANNEL`),
  `android/common/src/main/res/values/strings.xml` (`FlClash`),
  `android/service/.../VpnService.kt` (`setSession("FlClash")` — имя VPN в
  настройках Android), `.../modules/NotificationModule.kt`
  (`setContentTitle`), `.../models/NotificationParams.kt`, `.../FilesProvider.kt`
  (`COLUMN_TITLE`), `android/app/.../models/State.kt`.
- `lib/providers/action.dart:529` — имя временного файла `SlClash-update.apk`.
- **Не менять** схему `flclash://` в `AndroidManifest.xml`: ей пользуются
  провайдеры подписок для импорта (`flclash://install-config?url=…`).
  Добавить свою схему можно, старую удалять нельзя.

## 🔴 Аутентификация локального mixed/socks порта по умолчанию

**Проблема.** SlClash слушает `mixed-port` (по умолчанию 7890) на
localhost без аутентификации (`authentication: []`). Любое приложение на
устройстве (без разрешения на VPN) может ходить через этот порт в
туннель пользователя — обход per-app правил, утечка трафика в чужой
выход, деанонимизация (localhost-атака).

**Решение (набросок).**

- При первом запуске генерировать случайные учётные данные
  (`user`: 16+ символов, `password`: 32+ символа, CSPRNG) и хранить их в
  настройках приложения.
- Всегда передавать их в runtime-конфиг mihomo как `authentication:
  ["user:pass"]`; `skip-auth-prefixes` по умолчанию пустой (в том числе
  без `127.0.0.1/32`).
- Включено по умолчанию; в настройках — показать/скопировать/перегенерировать,
  явный выключатель с предупреждением.
- Учесть: TUN-режим не использует mixed-порт; HTTP-прокси системы Android
  (если где-то выставляется) не умеет авторизацию — проверить, какие сценарии
  приложения ходят через порт (медиа-проверки, `_clashDio` и т. п.), и
  передать им учётные данные.
- Реализация — в новых файлах (сервис учётных данных + точка подключения в
  сборке runtime-конфига), тесты на то, что конфиг всегда содержит
  `authentication`.

## Архитектура ядер-сайдкаров (шаг 2)

Подключаемые дополнительные ядра рядом с mihomo (отдельные процессы или
библиотеки), которые mihomo использует как outbound/provider.

Вопросы для проектирования:

- Формат модуля: отдельный `.so` в `jniLibs` + исполняемый бинарник через
  `nativeLibraryDir` vs отдельный процесс/сервис; жизненный цикл и
  перезапуск вместе с VPN.
- Связь с mihomo: локальный socks/http outbound на loopback с
  аутентификацией (см. пункт выше) или unix-socket; защита от доступа
  других приложений.
- Сборка: отдельный каталог (`sidecars/<name>/`), собственные патчи и
  submodule, свой шаг в buildkit без правок существующего Go-моста;
  кэш артефактов в CI по аналогии с `libclash.so`.
- UI: конфигурация сайдкара в профиле, логи, статус.
- Обновления: workflow по аналогии с `mihomo-core-update.yml`.
- Лицензии каждого ядра и их совместимость с GPL-3.0 (NOTICE).

## Размер APK

Замер 2026-09-27, mihomo v1.19.31, release arm64-v8a
(`flutter build apk --release --split-per-abi`, как в `release.yml`):
**57,1 МБ**. Debug — 115 МБ; разница — только debug-артефакты
(`kernel_blob.bin` 33 МБ JIT-ядра Dart вместо AOT `libapp.so` 5,4 МБ,
`libVkLayer_khronos_validation.so` 4,7 МБ), в release их нет.

| Что (сжато в APK) | МБ | Доля |
|---|---|---|
| `libclash.so` (Go-ядро, 64 МБ распакованным, уже stripped `-w -s`) | 21,7 | 38 % |
| Геобазы `assets/data`: `ASN.mmdb` 5,7, `GEOIP.metadb` 4,7, `GEOIP.dat` 4,6, `GEOSITE.dat` 1,3 | 16,3 | 29 % |
| `libflutter.so` + `libapp.so` | 10,7 | 19 % |
| ML Kit штрих-коды (`libbarhopper_v3.so` + модели), из `mobile_scanner` | 3,0 | 5 % |
| dex, ресурсы, шрифты (`Twemoji` 0,8), sqlite, quickjs и пр. | 5,4 | 9 % |

Что заметно раздувает и что можно сделать (ничего не реализовано):

1. **EasyTier в ядре — новое в v1.19.31.** В v1.19.30 (ядро SlClash) его не
   было. По символам `easytier` + `gopacket` — крупнейшие модули ядра.
   Сборка с тегом `no_easytier`: ядро 57,7 → 47,3 МБ распакованным
   (−10,4 МБ), ≈ −3,6 МБ в APK, и возвращает набор outbound к уровню SlClash
   v2.2.3. Реализация — одна строка `tags:` в
   `plugins/setup/buildkit/build_tool/build_config.yaml` (и в CI-командах
   `go test -tags=…`). Минус: outbound `easytier` в профилях перестанет
   работать. Дальше: `no_zerotier` (−1,0 МБ), `no_tailscale` (−7,3 МБ
   распакованным) — это уже удаление функций, которые были в SlClash.
2. **Три геобазы IP в двух форматах.** `GEOIP.dat` и `GEOIP.metadb` — одни и
   те же данные для разных `geodata-mode`, `ASN.mmdb` нужен только правилам
   `IP-ASN`. Все копируются из assets при первом запуске
   (`lib/core/controller.dart:79`). Оставить в APK одну базу под режим по
   умолчанию, остальное качать при первом использовании (URL уже есть в
   `GeoXUrl`) — ≈ −10 МБ. Это изменение логики приложения.
3. **ML Kit bundled → unbundled** (`dev.steenbakker.mobile_scanner.useUnbundled=true`
   в `android/gradle.properties`) — ≈ −3 МБ, но сканер QR начнёт требовать
   Google Play Services (у части пользователей прокси-клиентов их нет).
4. `useLegacyPackaging = true` (`android/app/build.gradle.kts`): `.so`
   сжаты в APK (меньше скачивание), но при установке распаковываются —
   занимают ≈ 97 МБ на устройстве сверх APK. Альтернатива — несжатые
   выровненные `.so` (APK ≈ +60 МБ, место на устройстве меньше). Оставить
   как есть, пока не станет проблемой.

## Прочее (найдено при разведке)

- **Апдейтер через сторонний прокси.** `lib/common/request.dart`
  (`checkForUpdate`) при недоступности `api.github.com` берёт метаданные
  релиза через `gh-proxy.com`, `lib/common/update.dart` качает APK сначала
  через него же. SHA-256 для проверки APK берётся из тех же метаданных, т. е.
  при fallback его определяет сторонний прокси. Android не установит
  обновление с другой подписью, но стоит: брать метаданные только с
  `api.github.com`, дополнительно сверять сертификат подписи скачанного APK
  с сертификатом установленного приложения, сделать зеркало опциональным.
- `pubspec.lock` SlClash сгенерирован более новым Flutter, чем их CI
  (3.41.9): `flutter pub get` на 3.41.9 откатывает `meta` 1.18→1.17,
  `test` 1.31→1.30, `test_api`/`test_core`. Решить при обновлении Flutter.
- `AGENTS.md` SlClash описывает их окружение; заменить/сократить, когда
  станет мешать.
- `tools/perf/` ссылается на `com.slclash.app*`.
- Предупреждение анализатора в `plugins/setup/buildkit/build_tool/lib/src/util.dart`
  (неиспользуемый импорт `dart:convert`) — из апстрима.
