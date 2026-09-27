# Выпуск релиза RoutaMi

Релиз собирает `.github/workflows/release.yml` для тега `vX.Y.Z`
(или `vX.Y.Z-rc.N` — тогда это prerelease). Запускается push тега или
вручную (Actions → Release → Run workflow, см. раздел 4). Workflow:

1. проверяет тег, что коммит есть в `main`, и что секреты подписи заданы
   (без них падает за секунды);
2. прогоняет весь CI (`ci.yml`: тесты + debug APK);
3. собирает Go-ядро с нуля (без кэша) и release APK arm64-v8a;
4. подписывает его ключом из секретов, проверяет `packageName`
   (`icu.routaterm.routami`) и что подпись **не** debug-ключом;
5. публикует GitHub Release с `RoutaMi-vX.Y.Z-arm64-v8a.apk`, файлом
   `.sha256`, версией ядра и SHA-256 сертификата подписи.

Встроенный апдейтер приложения смотрит `releases/latest` этого репозитория
и берёт первый `.apk` с `arm64-v8a` в имени — поэтому в релизе ровно один APK.

## 1. Создать release-keystore (один раз)

Нужен JDK (`keytool`). Команда на своём компьютере, **не** в репозитории:

```bash
keytool -genkeypair -v \
  -keystore routami-release.jks -storetype PKCS12 \
  -alias routami -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=RoutaMi, O=routaterm.icu"
```

- Придумайте длинный пароль (20+ символов, из менеджера паролей).
- В PKCS12 пароль ключа совпадает с паролем хранилища — keytool его не
  спрашивает отдельно. Значит `ANDROID_KEY_PASSWORD` = `ANDROID_KEYSTORE_PASSWORD`.
- Срок 10000 дней (~27 лет): Google Play требует срок после 2033 года.

Запишите отпечаток сертификата — по нему потом сверяются релизы:

```bash
keytool -list -v -keystore routami-release.jks -alias routami | grep SHA256
```

## 2. Завести секреты GitHub

Settings → Secrets and variables → Actions → **New repository secret**:

| Секрет | Значение |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | keystore в base64 одной строкой |
| `ANDROID_KEYSTORE_PASSWORD` | пароль хранилища |
| `ANDROID_KEY_ALIAS` | `routami` (alias из шага 1) |
| `ANDROID_KEY_PASSWORD` | пароль ключа (для PKCS12 — тот же пароль) |

Base64 без переносов строк:

```bash
base64 -w0 routami-release.jks > keystore.b64        # Linux
base64 -i routami-release.jks | tr -d '\n' > keystore.b64   # macOS
```
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("routami-release.jks")) | Set-Content keystore.b64   # Windows
```

Через `gh` (без копирования в буфер обмена):

```bash
gh secret set ANDROID_KEYSTORE_BASE64 -R Ametas/routa-mi < keystore.b64
gh secret set ANDROID_KEYSTORE_PASSWORD -R Ametas/routa-mi   # спросит значение
gh secret set ANDROID_KEY_ALIAS -R Ametas/routa-mi --body routami
gh secret set ANDROID_KEY_PASSWORD -R Ametas/routa-mi
rm keystore.b64
```

Никогда не кладите keystore, пароли или `android/local.properties` в
репозиторий (они в `.gitignore`), в issues, логи и чаты.

## 3. Резервная копия release-keystore — обязательно

**Потеря ключа необратима.** Android принимает обновление только с той же
подписью: без ключа установленные у пользователей копии RoutaMi нельзя
обновить — только удалить (с потерей данных) и поставить заново. GitHub
секреты прочитать обратно нельзя, поэтому **секрет — не резервная копия**.

Порядок:

1. Сразу после создания сделайте **минимум две офлайн-копии** в разных
   местах, например:
   - менеджер паролей с вложениями (Bitwarden/1Password/KeePassXC):
     файл `routami-release.jks` + пароль + alias + SHA-256 отпечаток;
   - зашифрованный носитель (VeraCrypt / LUKS / зашифрованный архив
     `7z -p -mhe=on`), хранящийся отдельно от компьютера.
2. Пароль храните **отдельно** от файла keystore (не в том же архиве в
   открытом виде).
3. Проверьте восстановление: из копии выполните
   `keytool -list -v -keystore <копия> -alias routami` и сверьте SHA-256.
4. Не храните keystore в облачных дисках и почте без шифрования.
5. Раз в год (и при смене компьютера/носителя) проверяйте, что копии
   читаются, и что отпечаток совпадает с указанным в последнем релизе.
6. Если ключ скомпрометирован, но ещё у вас на руках — можно выполнить
   ротацию ключа (APK Signature Scheme v3, `apksigner rotate`); если ключ
   потерян — ротация невозможна.

## 4. Выпустить релиз

**Вариант A — вручную из GitHub** (можно с телефона; так же релиз
запускает Claude Code через API): Actions → **Release** → **Run workflow**
→ Branch: `main` → tag: `v0.1.0` (или `v0.1.0-rc.1` для prerelease) →
Run workflow. Тег создаётся на текущем коммите `main` только после того,
как APK собран и проверен; упавший запуск ничего не оставляет — просто
запустите снова.

**Вариант B — push тега:**

```bash
git switch main && git pull
git tag -a v0.1.0 -m "RoutaMi v0.1.0"
git push origin v0.1.0
```

Не создавайте тег через «Draft a new release» в интерфейсе GitHub: Release
тогда уже существует, и workflow откажется его перезаписывать.

- `versionName` = тег без `v`, `versionCode` = unix-время сборки (растёт
  монотонно). Поле `version:` в `pubspec.yaml` для релизов не используется.
- Workflow откажется перезаписывать уже существующий Release. Чтобы
  пересобрать — удалите Release и тег, затем запустите снова.
- После публикации сверьте «Signing certificate SHA-256» в описании
  релиза с отпечатком из шага 1.

## 5. Постоянный debug-ключ для CI

Без него каждый runner генерирует свой случайный debug-ключ, и новый debug
APK из CI не встаёт поверх предыдущего («приложение не установлено»,
конфликт подписи). CI (`ci.yml`, job «Debug APK») берёт ключ из секрета
`ANDROID_DEBUG_KEYSTORE_BASE64` и кладёт его в
`~/.android/debug.keystore` — это стандартное место, откуда Android Gradle
Plugin берёт debug-подпись, поэтому Gradle-файлы не менялись.

Debug-ключ — **отдельный** от release-ключа (release-ключ для debug-сборок
не использовать никогда). Параметры фиксированы стандартом AGP: пароль
хранилища и ключа `android`, alias `androiddebugkey`.

1. Создать ключ (один раз):
   ```bash
   keytool -genkeypair -v \
     -keystore routami-debug.keystore -storetype PKCS12 \
     -storepass android -keypass android -alias androiddebugkey \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -dname "CN=Android Debug,O=Android,C=US"
   ```
   `CN=Android Debug` оставьте как есть: по нему `release.yml` отличает
   случайно подписанный debug-ключом релиз и отказывается его публиковать.
2. Завести секрет:
   ```bash
   base64 -w0 routami-debug.keystore | gh secret set ANDROID_DEBUG_KEYSTORE_BASE64 -R Ametas/routa-mi
   ```
3. (Необязательно) зафиксировать отпечаток, чтобы CI падал при подписи
   другим ключом:
   ```bash
   keytool -list -v -keystore routami-debug.keystore -storepass android -alias androiddebugkey \
     | grep 'SHA256:' | awk '{print $2}' | tr -d ':' | tr 'A-F' 'a-f'
   gh variable set ANDROID_DEBUG_CERT_SHA256 -R Ametas/routa-mi --body <отпечаток>
   ```
   Отпечаток каждой сборки выводится в Summary запуска CI.
4. Для локальных debug-сборок тем же ключом:
   `cp routami-debug.keystore ~/.android/debug.keystore` (сохраните старый,
   если он вам нужен).
5. Резервная копия — желательна (одна копия в менеджере паролей): потеря
   debug-ключа означает лишь одну переустановку debug-сборки
   (`icu.routaterm.routami.dev`) с потерей её данных.

Если секрет не задан (например, в форке), CI собирает APK со случайным
ключом и пишет предупреждение.

Debug-сборка (`icu.routaterm.routami.dev`) и релиз
(`icu.routaterm.routami`) — разные приложения и ставятся рядом.

Перед первым публичным релизом закройте пункты с пометкой
«обязательно до первого публичного релиза» в `docs/BACKLOG.md`.
