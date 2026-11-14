# NaiveProxy

Узлы `type: naive` работают в mihomo на сетевом стеке Chromium (Cronet),
поэтому TLS-отпечаток и HTTP/2 у них как у браузера Chrome.

## Конфиг

```yaml
proxies:
  - name: naive
    type: naive
    server: naive.example.org
    port: 443
    username: user
    password: pass
    # sni: other.example.org     # по умолчанию server
    # quic: true                 # HTTP/3 до сервера (не UDP-прокси)
    # udp-over-tcp: true         # UDP через сервер с sing-box UoT
    # certificate: /path/ca.pem  # свой CA (PEM или путь)
    # headers: {X-Foo: bar}
    # ech-opts: {enable: true}
```

`skip-cert-verify`, `client-fingerprint`, `fingerprint`, `alpn` и
`private-key` отклоняются: TLS делает Chromium, а самоподписанные
сертификаты ломают маскировку. Для своего сервера — `certificate` с CA.

Подписки-списки ссылок: `naive+https://user:pass@host:port#имя` и
`naive+quic://…` (параметр `extra-headers` — заголовки через `\r\n`).

## Устройство

- `core/patches/mihomo/naive-outbound.patch` — выход `naive` в mihomo,
  перенесён из [Herta-Network/mihomo](https://github.com/Herta-Network/mihomo)
  (`e51298ac`, GPL-3.0) на официальный
  [SagerNet/cronet-go](https://github.com/SagerNet/cronet-go). Наше
  отличие: движок Chromium стартует при первом подключении через узел, а не
  при загрузке конфига — неиспользуемые узлы подписки не держат память.
- Код собирается только с тегом `with_naive` (он в тегах сборки ядра,
  `plugins/setup/buildkit/build_tool/lib/src/options.dart`). Без тега узел
  отклоняется с понятной ошибкой.
- `core/naive/` статически линкует `libcronet.a` для android/arm64. Свои
  сокеты Cronet открывает через диалер mihomo, поэтому защита от петли
  через VPN (`protect`) и `dialer-proxy` работают как у остальных узлов.
  Имя сервера резолвит DNS mihomo для прокси-серверов.
- Cronet обёртывает `malloc`/`free` библиотеки (`-Wl,-wrap`), но по
  умолчанию передаёт их системному аллокатору: строки, выделенные в
  `libclash.so` и освобождаемые в `libcore.so`, остаются совместимы.
- Тест `core/naive/naive_test.go` поднимает локальный HTTP/2 CONNECT-сервер
  с паддингом Naive и гоняет трафик через настоящий Cronet (`libcronet.so`
  через purego на хосте). Отдельный шаг CI: теги
  `with_naive,with_purego`.

## Версии

`github.com/sagernet/cronet-go` закреплён в `core/go.mod` псевдоверсиями
(Chromium 154). Свежие коммиты ветки `go` появляются в прокси Go-модулей не
сразу; обновлять тем, что уже есть в `sum.golang.org`.

## Цена

`libclash.so` arm64: 93,9 → 105,1 МБ, сжатая 30,6 → 35,6 МБ (≈ +5 МБ к APK).
