# ZHOLAUSHY — Единое приложение (zholaushy_passenger)

## Что это
Одно Flutter Web приложение для пассажиров И водителей. Режим выбирается тоглом на экране входа.
Репозиторий `zholaushy_driver` больше не используется — всё слито сюда.

## Стек
- Flutter Web
- dart:html window.localStorage — НЕ shared_preferences (MissingPluginException на Web)
- Dio 5.x — всегда `Content-Type: application/json` в Options для POST/PATCH
- GoRouter
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

## Что реализовано ✅

### Пассажирский режим (home_screen.dart)
- Таб "Поездки": оранжевые карточки (open), синие (accepted с данными водителя)
- Кнопка "Создать заявку" → `_CreateRequestScreen`
- Тап на ожидающую заявку → `_OffersScreen` (список офферов)
- Таб "Попутки": поиск готовых поездок → `_BookingFormScreen`
- Форма заявки: маршрут, дата/время, места, оплата, адреса А/Б с доп. точками, для кого, комментарий
- Редактирование заявки (`_EditRequestScreen`) + отмена (DELETE)
- Принятие оффера: bottom sheet подтверждения адреса → `POST /trip-requests/{id}/accept/{offer_id}`

### Водительский режим (driver_home_screen.dart)
- Все экраны из бывшего zholaushy_driver слиты сюда
- `const String _driverApiBase` (не конфликтует с пассажирским `apiBase`)
- Выход удаляет `token` и `mode`

### Общее
- История поездок (`history_screen.dart`)
- Профиль пассажира (`profile_screen.dart`)
- Профиль водителя + авто (`driver_profile_screen.dart`) — сохраняет имя в `localStorage['name']`
- Данные автомобиля (`car_info_screen.dart`) — первичный + обновление (`?update=true`)
- Ожидание верификации (`pending_screen.dart`)
- Поддержка, Настройки, О приложении (`info_screens.dart`)

## Структура файлов
```
zholaushy_passenger/lib/
├── main.dart                      # GoRouter: /login, /register, /home, /history,
│                                  #           /driver-home, /car-info, /pending
├── fcm_service.dart               # Firebase Cloud Messaging
├── app_state.dart                 # ThemeMode, lang notifiers
└── screens/
    ├── login_screen.dart          # OTP + тоггл Пассажир/Водитель
    ├── register_screen.dart       # Новый пользователь: имя → OTP verify → home/car-info
    ├── home_screen.dart           # Пассажир: заявки, попутки
    ├── history_screen.dart        # История завершённых поездок
    ├── profile_screen.dart        # Профиль пассажира
    ├── driver_home_screen.dart    # Водитель: заявки пассажиров, мои поездки, отклики
    ├── driver_profile_screen.dart # Профиль водителя + авто
    ├── car_info_screen.dart       # Данные автомобиля
    ├── pending_screen.dart        # Ожидание верификации
    └── info_screens.dart          # Поддержка, Настройки, О приложении
```

## Что сделать дальше (план)
- [ ] Дизайн: цвета, шрифты, анимации, splash screen
- [ ] Foreground push: `FirebaseMessaging.onMessage` → SnackBar
- [ ] Экран активной поездки: пассажир принял оффер → данные водителя + кнопка "Отменить"
- [ ] История: тап → детали поездки (маршрут, водитель, адреса, цена)
- [ ] Pull-to-refresh на экране офферов
- [ ] Рейтинг водителя после завершения поездки
- [ ] Баланс водителя (UI после презентации)
