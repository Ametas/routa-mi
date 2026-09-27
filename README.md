# RoutaMi

RoutaMi — прокси-клиент для Android (arm64-v8a) на ядре
[mihomo](https://github.com/MetaCubeX/mihomo). Позже планируется десктопная
версия и подключаемые ядра-сайдкары (см. `docs/BACKLOG.md`).

## Что это за форк

RoutaMi — жёсткий форк [SlClash](https://github.com/songzhengpei/Slclash)
v2.2.3, который в свою очередь ответвился от
[FlClash](https://github.com/chen08209/FlClash) v0.8.93. История обоих
проектов сохранена; изменения из SlClash переносятся точечно через
`git cherry-pick`, решения по каждому коммиту ведутся в
[`UPSTREAM.md`](UPSTREAM.md).

Отличия от SlClash на данный момент:

- собственный applicationId `icu.routaterm.routami` и имя приложения;
  ставится рядом с SlClash, не заменяя его, и обновляется из релизов этого
  репозитория;
- ядро — официальный `MetaCubeX/mihomo` (сейчас v1.19.31) вместо зеркала
  SlClash, с патчами из `core/patches/mihomo/`;
- собственный CI и выпуск релизов.

Интерфейс и логика приложения пока совпадают с SlClash v2.2.3.

## Сборка

Требуются Flutter 3.41.9, Go 1.24, JDK 21, Android SDK 36 и NDK r28c —
`scripts/cloud-setup.sh` ставит их на Linux. Команды сборки и тестов — в
[`CLAUDE.md`](CLAUDE.md), выпуск релиза — в [`docs/RELEASE.md`](docs/RELEASE.md).

```bash
git clone --recurse-submodules https://github.com/Ametas/routa-mi
```

## Лицензия

GPL-3.0, см. [`LICENSE`](LICENSE). Авторство FlClash, SlClash и mihomo —
в [`NOTICE`](NOTICE).
