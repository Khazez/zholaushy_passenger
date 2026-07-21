# ZHOLAUSHY — Единое приложение (zholaushy_passenger)

## Что это
Одно Flutter Web приложение для пассажиров И водителей. Режим выбирается тоглом на экране входа.
Репозиторий `zholaushy_driver` больше не используется — всё слито сюда.

## Стек
- Flutter Web
- dart:html window.localStorage — НЕ shared_preferences (MissingPluginException на Web)
- Dio 5.x — всегда `Content-Type: application/json` в Options для POST/PATCH
- GoRouter
- Google Fonts Inter (`google_fonts: ^6.2.1`) — `fontFamily` выставлен глобально в ThemeData
- Бэкенд: http://localhost:8000/api/v1
- Запуск: `flutter run -d chrome --web-port=3001` (порт 3000 занят админкой)

## Auth (OTP-based)
- Токен: `localStorage['token']` — единый для обоих режимов
- Режим: `localStorage['mode']` = 'passenger' | 'driver'
- Имя:   `localStorage['name']`
- Логин: `POST /auth/send-otp` → `POST /auth/verify-otp?phone=&code=&role=`
- Новый пользователь: бэкенд возвращает 400 "Новый пользователь — укажите имя" → `/register`
- `role` передаётся в `verify-otp` — бэкенд обновляет роль пользователя в БД (critical для driver!)

## Тоггл Пассажир / Водитель
- Показывается только на шаге 1 (ввод телефона) экрана логина
- Определяет `localStorage['mode']` и `role` в JWT

## Флоу водителя (после логина с режимом "Водитель")
1. `GET /drivers/profile`
   - 404 → `/car-info` (создать профиль машины)
   - `is_verified=false` → `/pending`
   - `is_verified=true` → `/driver-home`
2. `/car-info` → `POST /drivers/profile` → `/pending`
3. `/pending` → поллинг `is_verified` → `/driver-home` когда одобрен

## Адресная модель (важно!)
`extra_pickups` и `extra_destinations` — списки объектов `{address: str, entrance: str?}`.

В Flutter используется класс `_AddrPair` (home_screen.dart, top-level):
```dart
class _AddrPair {
  final TextEditingController address;
  final TextEditingController entrance;
  ...
  Map<String, dynamic> toMap() → {address: ..., ?entrance: ...}
}
```
НЕ отправлять как plain strings — бэкенд ожидает объекты.

## Дизайн-система (theme.dart)

### Цвета
- `kNavy = #0D1F6E` — основной тёмный (текст, AppBar)
- `kTeal = #17A8C4` — акцент (кнопки, иконки)
- `kBg = #F4F7FF` — фон страниц
- `kCard = #FFFFFF` — фон карточек
- `kGradient` — LinearGradient(topLeft→bottomRight, [kNavy, kTeal])
- `kGradientVertical` — LinearGradient(top→bottom, [kNavy, #1565C0, kTeal])

### Тёмная тема
- `kDarkBg = #0F1729`, `kDarkCard = #1A2744`, `kDarkText = #E8EDF8`

### Компоненты
- `AppBarOrnament` — flexibleSpace для AppBar: рисует градиент + угловые казахские дуги через CustomPainter (foregroundPainter поверх gradient)
- `BodyOrnament(child: ...)` — Stack с CustomPainter угловых дуг поверх тела экрана (navy, opacity 0.07)
- `AppColors` extension на BuildContext: `context.bgC`, `.cardC`, `.textC`, `.subC`, `.iconBgC`, `.iconC`, `.shadowC`, `.divC`

### Шрифт
- `fontFamily: GoogleFonts.inter().fontFamily` установлен в обоих ThemeData (light + dark)
- Работает для всех Text виджетов, даже с явным TextStyle

## Что реализовано ✅

### Пассажирский режим (home_screen.dart)
- Таб "Поездки": карточки open/accepted с динамическим заголовком (Водитель найден / Выехал / Подъехал)
- Кнопка "Создать заявку" → `_CreateRequestScreen`
- Pull-to-refresh на экране офферов
- Принятие оффера без подтверждения адреса (напрямую POST)
- Отмена поездки: сначала DELETE /bookings/{id}, фоллбэк DELETE /trip-requests/{id}
- Завершённые поездки скрываются после оценки (localStorage `rated_trips`)
- Рейтинг водителя после поездки + кнопка "Позже"
- Экран активной поездки (`active_trip_screen.dart`) — поллинг 15с, статус-баннеры, автонавигация после завершения

### Водительский режим (driver_home_screen.dart)
- Табы: Заявки / Поездки / Отклики / Баланс
- Кнопки "Выехал" / "Подъехал" сохраняются в БД (is_departed, is_arrived) — не сбрасываются при переключении табов
- Баланс водителя: реальные данные с `GET /drivers/balance`, кнопка "Пополнить" (диалог → обратитесь к админу)
- Списание 50₸ при каждом отклике, 402 ошибка при нехватке

### Push-уведомления ✅
- Foreground: FirebaseMessaging.onMessage → SnackBar (main.dart)
- Все события: новый отклик, принятие/отклонение, отзыв, отмена, завершение, Выехал, Подъехал

### Дизайн ✅ (все экраны)
- splash_screen.dart — логотип добавлен (21.07.2026): `assets/images/zholaushy_icon.png`
  (машина + гео-метка, нарисованы белым, стоят прямо на градиенте без карточки-подложки;
  внутренние детали перекрашены в kNavy/kTeal) с анимацией появления —
  overshoot-масштаб лого → буквы wordmark по одной → пульсирующие точки загрузки
- login_screen.dart, register_screen.dart
- home_screen.dart — полностью (все внутренние экраны)
- active_trip_screen.dart — статус-баннеры с анимацией пульса
- driver_home_screen.dart — все табы
- history_screen.dart, profile_screen.dart, driver_profile_screen.dart
- car_info_screen.dart, pending_screen.dart
- info_screens.dart (Поддержка, Настройки, О приложении)

### Bottom sheet вместо системных попапов ✅ (16.07.2026)
Общие виджеты в `lib/widgets/`, используются и в пассажирском, и в
водительском режиме — вместо дублированного кода в двух экранах:
- `account_drawer.dart` — `AccountDrawer`, боковая шторка (`Scaffold.endDrawer`)
  вместо `PopupMenuButton`: аватар+имя+роль кликабельны целиком → профиль,
  плоские иконки, группы через разделители, «Выйти» снизу
- `route_picker_sheet.dart` — `showRoutePickerSheet()`, bottom sheet с поиском
  и ценой вместо `DropdownButtonFormField` (было в 3 местах: 2 у пассажира,
  1 у водителя)
- `date_time_sheet.dart` — `showDateTimeSheet()` + виджет-триггер
  `DateTimeField`, bottom sheet с карточками дней и колесом часы:минуты
  (24-часовой формат, без AM/PM) вместо кастомного степпера/нативных пикеров

### LocalStorage
- `rated_trips` — comma-separated trip IDs уже оценённых поездок

## Структура файлов
```
zholaushy_passenger/lib/
├── main.dart                      # GoRouter + foreground push SnackBar
├── theme.dart                     # Цвета, AppBarOrnament, BodyOrnament, AppColors
├── fcm_service.dart               # Firebase Cloud Messaging
├── app_state.dart                 # ThemeMode, lang notifiers
├── screens/
│   ├── splash_screen.dart         # Градиент + лого (zholaushy_icon.png) с анимацией (21.07.2026)
│   ├── login_screen.dart          # OTP + тоггл Пассажир/Водитель
│   ├── register_screen.dart       # Новый пользователь
│   ├── home_screen.dart           # Пассажир: заявки, попутки, активная карточка
│   ├── active_trip_screen.dart    # Экран активной поездки (статус-баннеры, отмена)
│   ├── history_screen.dart        # История завершённых поездок + детали
│   ├── profile_screen.dart        # Профиль пассажира + рейтинг
│   ├── driver_home_screen.dart    # Водитель: заявки, поездки, отклики, баланс
│   ├── driver_profile_screen.dart # Профиль водителя + авто
│   ├── car_info_screen.dart       # Данные автомобиля
│   ├── pending_screen.dart        # Ожидание верификации
│   └── info_screens.dart          # Поддержка, Настройки, О приложении
└── widgets/
    ├── avatar_picker.dart         # AvatarView (чужой, только показ) + AvatarPicker (свой, загрузка)
    ├── account_drawer.dart        # AccountDrawer — боковая шторка меню профиля
    ├── route_picker_sheet.dart    # showRoutePickerSheet() — bottom sheet выбора маршрута
    └── date_time_sheet.dart       # showDateTimeSheet() + DateTimeField — bottom sheet даты/времени
```

## Деплой (Railway)
- **Публичный URL:** https://zholaushypassenger-production.up.railway.app/
- Тот же Railway-проект: workspace `trustworthy-patience`, environment `production`, сервис `zholaushy_passenger`
- `Dockerfile`: multi-stage — Flutter SDK ставится через `git clone --depth 1 -b stable https://github.com/flutter/flutter.git` (НЕ готовый образ `ghcr.io/cirruslabs/flutter` — там версии отстают от `pubspec.yaml` требования `^3.12.2` Dart SDK), раздача статики через `nginx:alpine`
- Порт берётся из `$PORT` через nginx envsubst-темплейт (`nginx.conf.template` → `/etc/nginx/templates/default.conf.template`), т.к. Railway пробрасывает порт динамически
- `API_BASE` передаётся как `--dart-define` через Docker build-arg (см. `lib/config.dart`), в Railway Variables: `API_BASE=https://taxi-production-8544.up.railway.app/api/v1`
- OTP-логин для демо (нет реального SMS-шлюза): тестовые номера с фиксированным кодом `0000` — `+77009998877` (пассажир), `+77001112233`/`+77001112244` (верифицированные тестовые водители)

## Что НЕ сделано (после МВП)
- [ ] WebSocket — real-time офферы (сейчас поллинг каждые N секунд)
- [ ] Пополнение баланса через интерфейс (сейчас только через admin API POST /drivers/balance/topup)
- [ ] Списание за отклик возврат при отзыве оффера (сейчас не возвращается)
- [ ] Реальная оплата (Kaspi/карта) — интеграция после презентации
- [ ] Admin-панель: страница пользователей, детали водителя, экспорт CSV
- [ ] iOS/Android нативные приложения (сейчас только Flutter Web PWA)
- [ ] Казахские орнаменты в AppBar — визуально не отображаются из-за проблем с Flutter Web CustomPainter в flexibleSpace
