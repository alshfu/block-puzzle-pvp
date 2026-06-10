# macOS: авторизация Google + PvP — настройка

Код для нативного входа на macOS уже в репозитории (`lib/auth/auth_controller.dart`
— ветка `_signInWithGoogleNative` через `google_sign_in` 7.x → Firebase-credential;
`lib/firebase_options.dart` — конфиг `macos`; `macos/Runner/Info.plist` — URL-схема).
Осталось **заполнить значения из консолей** — это шаги, которые делает владелец
проекта (у AI-ассистента доступа к Firebase/Google Cloud нет).

> **Bundle id macOS:** `com.alshfu.blockDuel` (`macos/Runner/Configs/AppInfo.xcconfig`).
> **Firebase-проект:** `blockduel-web`.

---

## PvP на macOS — уже работает (только собирать с prod-флагами)

Сетевой entitlement `com.apple.security.network.client` в `macos/Runner/Release.entitlements`
включён, online-слой платформу не гейтит. Единственное, что нужно — собирать
macOS с тем же адресом сервера, что и web (иначе клиент идёт на дефолтный
`localhost:1999`):

```bash
npm run build:macos        # flutter build macos --release + --dart-define PARTY_HOST/PARTY_TLS
npm run run:macos:prod     # то же для `flutter run` (локальная проверка PvP)
```

Проверка: запустить → Онлайн → матчмейкинг находит соперника/бота, матч идёт.

---

## Авторизация Google на macOS — шаги в консоли

### 1. Зарегистрировать macOS-приложение в Firebase
Firebase Console → проект **`blockduel-web`** → ⚙️ Project settings → *Your apps* →
**Add app** → **Apple (iOS+/macOS)**:
- **Bundle ID:** `com.alshfu.blockDuel`
- скачать **`GoogleService-Info.plist`**.

Из него (или из карточки приложения) взять:
- `API_KEY`  → это `apiKey`;
- `GOOGLE_APP_ID` (вид `1:585493330974:ios:...`) → это `appId`;
- `CLIENT_ID` (вид `...apps.googleusercontent.com`) → для Google Sign-In;
- `REVERSED_CLIENT_ID` (вид `com.googleusercontent.apps...`) → URL-схема.

### 2. Прописать значения в `lib/firebase_options.dart` → `macos`
Заменить заглушки:
```dart
static const FirebaseOptions macos = FirebaseOptions(
  apiKey: '<API_KEY>',                 // было REPLACE_ME_macos_apiKey
  appId: '1:585493330974:ios:<...>',   // было REPLACE_ME_macos_appId
  messagingSenderId: '585493330974',   // уже верно
  projectId: 'blockduel-web',          // уже верно
  storageBucket: 'blockduel-web.firebasestorage.app', // уже верно
  iosBundleId: 'com.alshfu.blockDuel', // уже верно
);
```
(Как только `appId` перестаёт начинаться с `REPLACE_ME`, `DefaultFirebaseOptions.macosConfigured`
становится `true` и Firebase на macOS поднимается.)

### 3. Прописать Google client id в `macos/Runner/Info.plist`
Заменить заглушки `REPLACE_ME`:
- `GIDClientID` → `<CLIENT_ID>` (полный, `...apps.googleusercontent.com`);
- `CFBundleURLSchemes[0]` → `<REVERSED_CLIENT_ID>` (`com.googleusercontent.apps...`).

### 4. (Если входа всё ещё нет) проверить OAuth consent / клиента
Google Cloud Console → проект `blockduel-web` → *APIs & Services* → *Credentials*:
убедиться, что есть OAuth-клиент типа **iOS** с этим bundle id (Firebase создаёт
его автоматически при шаге 1). OAuth consent screen должен быть настроен (тип
External, опубликован или тестовые пользователи добавлены).

### 5. Собрать и проверить
```bash
flutter pub get
npm run run:macos:prod      # запустить нативное приложение
```
Настройки → «Войти через Google» → должен открыться системный Google-флоу →
после входа подтягивается Firestore-синк (`users/{uid}`). `signOut` выходит и из
Google-сессии.

---

## Замечания
- **Firestore-правила** (`firestore.rules`) общие для всех платформ — отдельно
  для macOS ничего не нужно; не забудь их задеплоить (`npm run deploy:rules`).
- **Подпись:** для распространения вне своей машины .app нужно подписать/
  нотаризовать (Developer ID); неподписанный запускается через ПКМ→Открыть.
- **iOS/Android:** тот же код входа подойдёт — нужно лишь аналогично
  зарегистрировать приложения в Firebase и заполнить опции/URL-схемы.
