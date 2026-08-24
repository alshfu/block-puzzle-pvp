# BlockDuel 9×9 — чек-лист выхода в прод (Play Store + App Store)

Честная карта: **что уже готово в коде** и **что можешь сделать только ты**
(аккаунты, сертификаты, консоли, художественные ассеты). У AI-ассистента нет
доступа к Apple Developer / Google Play Console / Firebase Console / твоим
ключам подписи — эти шаги за владельцем проекта.

Версия приложения: **2.0.0+1** (`pubspec.yaml`). Bundle id: iOS/macOS
`com.alshfu.blockDuel`, Android `com.alshfu.block_duel`.

---

## ✅ Готово в коде (проверяемо)

- **Тесты:** 426 Flutter + 94 TS зелёные; `flutter analyze` и `tsc` — 0 проблем.
- **Безопасность:** `npm audit` — 0 уязвимостей.
- **Сборки под все 4 платформы** проходят: Web (release), Android (APK/AAB),
  macOS (.app), iOS (.app, `--no-codesign`). См. историю сессии в `CHANGELOG.md`.
- **iOS min-версия 15.0** (требование firebase-core; поднято с 13.0).
- **Android release-signing** настроен через `android/key.properties` (fallback на
  debug, если файла нет — чтобы CI/локальные сборки не падали).
- **Имя приложения** на всех платформах — «BlockDuel» (Android label поправлен).
- **PvP-сервер:** серверные фиксы (HIGH-краш, resign-в-waiting, heartbeat, flush
  лидерборда) закоммичены — **нужен деплой на VPS** (см. ниже).

---

## 🔴 Общие блокеры (нужны для ОБОИХ сторов)

### 1. Художественные ассеты (иконки/сплэш/скриншоты)
Сейчас игра почти полностью **процедурная** (см. `ASSETS.md`), но для сторов нужны:
- [ ] **Иконка приложения** 1024×1024 (мастер) → адаптивные иконки Android +
      iOS AppIcon. Рекомендую пакет `flutter_launcher_icons` (добавить в
      `dev_dependencies`, конфиг в `pubspec.yaml`, `dart run flutter_launcher_icons`).
- [ ] **Splash** (по желанию) — `flutter_native_splash`.
- [ ] **Скриншоты** для листингов (телефон/планшет; несколько экранов игры).
- [ ] **Feature graphic** (Play, 1024×500) и промо-арт по вкусу.

### 2. Firebase native-конфиг (Google-вход на mobile/desktop)
Web-вход работает; для **iOS/macOS/Android** нужно заполнить значения из
Firebase/Google Cloud Console — см. **`MACOS_AUTH_SETUP.md`** (те же шаги для iOS):
- [ ] Зарегистрировать iOS/macOS/Android-приложения в проекте `blockduel-web`.
- [ ] Заполнить `GIDClientID` + URL-схему в `Info.plist` (iOS/macOS).
- [ ] Проверить `google-services.json` (Android) / `GoogleService-Info.plist` (iOS).
- [ ] `flutterfire configure` обновит `lib/firebase_options.dart` при необходимости.
> Без этого приложение **работает офлайн** (гость), но кросс-девайс-синк и
> облачные ачивки на mobile недоступны.

### 3. Политика конфиденциальности (обязательна для обоих сторов)
- [ ] Страница Privacy Policy (публичный URL). Приложение использует Firebase
      Auth/Firestore (Google-аккаунт, uid, ник/аватар, прогресс) — это надо описать.
- [ ] Заполнить формы Data Safety (Play) и App Privacy (App Store).

---

## 🤖 Google Play — пошагово (делает владелец)

1. [ ] Аккаунт **Google Play Console** (разовый взнос $25).
2. [ ] **Ключ подписи (upload keystore):**
   ```bash
   keytool -genkey -v -keystore ~/blockduel-upload.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
3. [ ] Создать `android/key.properties` (НЕ коммитить — уже в `.gitignore`):
   ```properties
   storePassword=<пароль хранилища>
   keyPassword=<пароль ключа>
   keyAlias=upload
   storeFile=/абсолютный/путь/blockduel-upload.jks
   ```
4. [ ] Собрать App Bundle:
   ```bash
   flutter build appbundle --release \
     --dart-define=PARTY_HOST=pvp.alshfu.com --dart-define=PARTY_TLS=1
   ```
   Артефакт: `build/app/outputs/bundle/release/app-release.aab`.
5. [ ] Play App Signing: загрузить AAB, дать Google управлять ключом релиза.
6. [ ] Заполнить листинг (описание/скриншоты/иконка/feature graphic/категория
       «Игры → Головоломки»), Data Safety, возрастной рейтинг (IARC).
7. [ ] Internal testing → Closed → Production. Поднять `versionCode` (`2.0.0+2`…)
       на каждую загрузку.

---

## 🍎 App Store — пошагово (делает владелец)

1. [ ] **Apple Developer Program** ($99/год).
2. [ ] В Xcode: команда/Team, автоматическая подпись, provisioning profile;
       Bundle ID `com.alshfu.blockDuel` зарегистрировать в Developer-портале.
3. [ ] Firebase iOS-конфиг (см. блокер №2).
4. [ ] Собрать архив: `flutter build ipa --release --dart-define=PARTY_HOST=pvp.alshfu.com --dart-define=PARTY_TLS=1`
       (или через Xcode: Product → Archive), затем Distribute → App Store Connect.
5. [ ] **App Store Connect:** приложение, листинг (описание/скриншоты 6.7"+6.1"+
       iPad/по требованиям), App Privacy, возрастной рейтинг, экспорт-compliance.
6. [ ] TestFlight → Submit for Review. Поднять build number на каждую загрузку.

---

## 🌐 Web (уже в проде) и 🖥 PvP-сервер

- **Web:** прод на GitHub Pages, автодеплой Actions на push в `main`
  (`npm run deploy:flutter` — запасной путь). См. `DEPLOY.md`.
- **PvP-сервер (VPS):** после серверных фиксов сессии выполнить на VPS:
  ```bash
  git pull && systemctl restart blockduel-pvp
  ```
  Иначе HIGH-фикс краша и остальные серверные правки **не активны**.
- Пост-cutover hardening (по желанию): `REQUIRE_ROOM_TOKEN=1`, `ALLOWED_ORIGINS`
  (см. `DEPLOY.md`).

---

## Перед каждой отправкой (быстрый прогон)

```bash
flutter analyze            # 0 issues
flutter test               # всё зелёное
npm test                   # ядро+сервер
flutter build appbundle --release   # Android
flutter build ipa --release         # iOS
```

Связанные доки: `MACOS_AUTH_SETUP.md` (auth), `ASSETS.md` (арт), `DEPLOY.md`
(web/сервер), `CHANGELOG.md` (что сделано в сессии закалки).
