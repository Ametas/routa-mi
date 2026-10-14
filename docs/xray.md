# Xray-core — второе ядро

Профиль работает либо на mihomo (Clash YAML), либо на Xray (Xray JSON).
Одновременно запущено одно ядро.

## Устройство

- Оба ядра собраны в одну `libclash.so` (одна Go-среда в процессе
  `:remote`; два Go `c-shared` в одном процессе конфликтуют).
- `core/xray/` — обёртка Xray-core: `Validate`, `Start(config, fd)`,
  `Reload` (с тем же TUN-дескриптором), `Stop` (закрывает fd, `GC` +
  `FreeOSMemory`), `SelectOutbound` (балансировщик, без перезапуска),
  `OutboundTraffic`, `SetProtect`, `SetLogHandler`.
- `core/engine.go` — активное ядро и экшены `xrayValidate`, `xraySetup`,
  `xrayStop`, `xraySelect`, `xrayTraffic`. `xraySetup` выключает mihomo
  (`executor.Shutdown`), `xrayStop` возвращает устройство mihomo — дальше
  приложение настраивает его как при старте.
- TUN: Xray 26.x принимает fd от VpnService через `xray.tun.fd`
  (`tun`-вход, gVisor). Конфиг с `tun`-входом стартует только в `startTUN`.
  Свой `Close` у Xray fd не закрывает — закрывает `core/xray`.
- Сокеты Xray защищаются тем же JNI-колбэком `protect`, что у mihomo
  (`RegisterDialerController`).
- Узлы JSON-подписки (массив конфигов) — выходы одного экземпляра под
  балансировщиком; выбор узла — `SetOverrideTarget`, без перезапуска.

## Цена

Go 1.26 (требование Xray 26.x) и Xray: `libclash.so` arm64 64,3 → 93,8 МБ,
сжатая 21,7 → 30,6 МБ (≈ +9 МБ к APK).

## Этапы

1. Go 1.26.9 — сделано.
2. Движок Xray в ядре — `core/xray`, `core/engine.go`, `core/tun_xray.go` —
   сделано.
3. Профиль — сделано: поле `core` (Drift v5), переключатель mihomo / Xray
   в «Импорт по URL», ядро определяется по содержимому (`detectProfileCore`:
   JSON-объект или массив с `outbounds`/`inbounds` → Xray, YAML → mihomo,
   ссылки — выбранное ядро), проверка профиля его ядром, UA
   `RoutaMi/<версия> xray/<версия>`, бейдж ядра. Запуск Xray-профиля —
   этап 4.
4. Запуск Xray-профиля — сделано.
   - `lib/services/xray_config/xray_runtime_config.dart` собирает конфиг:
     все узлы (элементы JSON-массива) с тегами `nNNN-*` под балансировщиком
     `routami-select`, цепочки `dialerProxy`/`proxySettings` переименованы;
     маршрутизация и DNS из первого элемента, правила на узел ведут в
     балансировщик; свои входы (TUN, mixed-порт = SOCKS с HTTP-фолбэком и
     авторизацией, локальный VLESS); режимы Rule/Global/Direct; статистика.
   - Узлы — группа `Proxy` на экране прокси; выбор — `xraySelect`, без
     перезапуска; сохраняется в `selectedMap` профиля.
   - Гео-правила Xray берут `GeoIP.dat`/`GeoSite.dat` mihomo через симлинки
     в `xray-assets/`.
   - Смена ядра при работающем VPN пересоздаёт TUN (`reconfigureSettings`).
   - Трафик на главном экране — из счётчиков Xray (`getTrafficSnapshot`).
5. Несовместимые с Xray настройки — тусклые, по нажатию объясняют почему
   (`MihomoOnly`) — сделано: hosts, IPv6 ядра, unified-delay, append-system-DNS,
   find-process, tcp-concurrent, geodata-loader, external-controller, стек
   TUN, экран DNS, соединения и запросы, добавленные правила, скрипты,
   медиа-проверка.
6. Задержка для Xray — сделано: замер через работающий экземпляр с
   принудительным выходом (`session.SetForcedOutboundTagToContext`, как
   observatory Xray), без второго экземпляра. Фикстура конфига приложения
   проверяется настоящим Xray (`core/configfixture/xray_runtime_test.go`).
   Медиа-проверка для Xray — позже (сейчас тусклая).
