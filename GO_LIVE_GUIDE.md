# Go-Live: генерация keystore и заполнение Firebase-конфига

Два самых частых «застревания» перед публикацией — расписаны по шагам.
Дополняет `RELEASE_CHECKLIST.md`.

---

## 1. Android upload-keystore (подпись для Play Store)

Keystore — это твой «паспорт разработчика» для Android. Им подписывается каждый
релиз. **Потеряешь — не сможешь обновлять приложение**, поэтому забэкапь его.

### 1.1. Сгенерировать keystore

```bash
keytool -genkey -v \
  -keystore ~/blockduel-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

`keytool` идёт с JDK (в Android Studio: `<studio>/jbr/bin/keytool`). Спросит:
- **пароль хранилища** (storePassword) — придумай надёжный;
- имя/организацию/город (можно оставить условные);
- **пароль ключа** (keyPassword) — можно тот же, что и storePassword.

`-validity 10000` — ~27 лет (Google требует срок годности до 2033+; этого хватит).

### 1.2. Создать `android/key.properties`

Файл **уже в `.gitignore`** — секреты не попадут в git. Создай его:

```properties
storePassword=ТВОЙ_ПАРОЛЬ_ХРАНИЛИЩА
keyPassword=ТВОЙ_ПАРОЛЬ_КЛЮЧА
keyAlias=upload
storeFile=/Users/al_sh/blockduel-upload.jks
```

> `storeFile` — **абсолютный** путь к `.jks`. Наш `android/app/build.gradle.kts`
> уже читает этот файл: если он есть — подписывает релиз твоим ключом; если нет —
> падает на debug (чтобы CI/локальные сборки не ломались).

### 1.3. Собрать подписанный App Bundle

```bash
flutter build appbundle --release \
  --dart-define=PARTY_HOST=pvp.alshfu.com --dart-define=PARTY_TLS=1
```

Результат: `build/app/outputs/bundle/release/app-release.aab`.
Проверить, что подписан именно твоим ключом:

```bash
cd android && ./gradlew :app:signingReport | grep -A4 "Variant: release"
# Store: должен указывать на blockduel-upload.jks, НЕ на debug.keystore
```

### 1.4. Play Console

- Загрузи `.aab` в Play Console → **Play App Signing** включи (Google хранит
  ключ релиза, ты — только upload-ключ; так безопаснее при утере).
- Забэкапь `blockduel-upload.jks` + пароли в надёжное место (менеджер паролей).

---

## 2. Firebase-конфиг для входа на mobile/desktop

Web-вход уже работает. Для **macOS / iOS / Android** нужно заполнить значения из
консолей — у AI-ассистента доступа туда нет, это делаешь ты. Проект в Firebase:
**`blockduel-web`**.

### 2.1. Зарегистрировать приложение в Firebase Console

1. [console.firebase.google.com](https://console.firebase.google.com) → проект
   `blockduel-web` → ⚙️ **Project settings** → **Your apps** → **Add app**.
2. Выбери платформу (**iOS+** для iOS/macOS, **Android** для Android).
3. **Bundle ID / Package name:**
   - iOS/macOS: `com.alshfu.blockDuel`
   - Android: `com.alshfu.block_duel`
4. Скачай конфиг:
   - iOS/macOS → **`GoogleService-Info.plist`**
   - Android → **`google-services.json`**

### 2.2. Заполнить `lib/firebase_options.dart` (macOS/iOS)

Открой `GoogleService-Info.plist` и найди значения. Замени заглушки
`REPLACE_ME_*` в `DefaultFirebaseOptions.macos`:

```dart
static const FirebaseOptions macos = FirebaseOptions(
  apiKey: '<API_KEY>',                    // ключ API_KEY из plist
  appId: '1:585493330974:ios:<...>',      // GOOGLE_APP_ID из plist
  messagingSenderId: '585493330974',      // уже верно
  projectId: 'blockduel-web',             // уже верно
  storageBucket: 'blockduel-web.firebasestorage.app',
  iosBundleId: 'com.alshfu.blockDuel',    // уже верно
);
```

> Как только `appId` перестаёт начинаться с `REPLACE_ME`, геттер
> `DefaultFirebaseOptions.macosConfigured` вернёт `true` и приложение начнёт
> использовать Firebase на macOS. Проще всего — прогнать `flutterfire configure`
> (CLI сам подставит корректные значения во все платформы).

Альтернатива (рекомендуется): установить FlutterFire CLI и сгенерировать всё
автоматически —

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=blockduel-web
```

### 2.3. Google Sign-In: Client ID и URL-схема (iOS/macOS)

В `GoogleService-Info.plist` есть `CLIENT_ID` и `REVERSED_CLIENT_ID`.

1. **`Info.plist`** (`ios/Runner/Info.plist`, `macos/Runner/Info.plist`) — заменить
   заглушку:
   ```xml
   <key>GIDClientID</key>
   <string><CLIENT_ID>.apps.googleusercontent.com</string>
   ```
2. Добавить URL-схему (для возврата из браузера Google после входа):
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string><REVERSED_CLIENT_ID></string>  <!-- com.googleusercontent.apps.585493... -->
       </array>
     </dict>
   </array>
   ```

### 2.4. Android

1. Положить `google-services.json` в `android/app/`.
2. Добавить SHA-1/SHA-256 отпечаток твоего keystore в Firebase Console
   (Project settings → Your apps → Android → **Add fingerprint**) — иначе
   Google Sign-In на Android не заработает:
   ```bash
   keytool -list -v -keystore ~/blockduel-upload.jks -alias upload | grep SHA
   ```
   (для отладки добавь и SHA debug-ключа: `~/.android/debug.keystore`, пароль `android`).

### 2.5. Проверка

- `firestore.rules` уже безопасны — при желании задеплой: `npm run deploy:rules`.
- Запусти на устройстве и войди через Google; в Firestore появится документ
  `users/{uid}` (кросс-девайс синк через `SyncController` → `CloudRepo`).

> Без этих шагов приложение **работает как гость** (весь офлайн-прогресс на
> устройстве) — это нормально для первого запуска в стор; облачный синк можно
> включить позже обновлением.

Связанное: `MACOS_AUTH_SETUP.md`, `RELEASE_CHECKLIST.md`, `firestore.rules`.
