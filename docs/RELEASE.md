# Выпуск релиза RoutaMi

Релиз собирает `.github/workflows/release.yml` при push тега `vX.Y.Z`
(или `vX.Y.Z-rc.N` — тогда это prerelease). Workflow:

1. проверяет, что тег стоит на коммите из `main`;
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

```bash
git switch main && git pull
git tag -a v0.1.0 -m "RoutaMi v0.1.0"
git push origin v0.1.0
```

- `versionName` = тег без `v`, `versionCode` = unix-время сборки (растёт
  монотонно). Поле `version:` в `pubspec.yaml` для релизов не используется.
- Workflow откажется перезаписывать уже существующий Release. Чтобы
  пересобрать — удалите Release и тег, затем создайте тег заново.
- После публикации сверьте «Signing certificate SHA-256» в описании
  релиза с отпечатком из шага 1.

Перед первым публичным релизом закройте пункты с пометкой
«обязательно до первого публичного релиза» в `docs/BACKLOG.md`.
