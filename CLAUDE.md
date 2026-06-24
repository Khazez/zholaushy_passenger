# ZHOLAUSHY — Приложение пассажира (zholaushy_passenger)

## Стек
- Flutter Web
- dart:html window.localStorage — НЕ shared_preferences (MissingPluginException на Web)
- Dio 5.x — всегда `Content-Type: application/json` в Options для POST/PATCH
- GoRouter
- Бэкенд: http://localhost:8000/api/v1

## Auth
- Токен: localStorage['token']
- Логин: POST /api/v1/auth/login → {phone, password} → {access_token}
- После register нужен отдельный login (register возвращает только message для пассажира)
- Для водителей register возвращает access_token сразу (role=driver)

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

### Таб "Поездки"
- Оранжевые карточки: заявки со статусом open, показывают badge "N отклик(ов)"
- Синие карточки: заявки со статусом accepted (с данными водителя)
- Брони (bookings) убраны с главного экрана
- Кнопка "Создать заявку" → _CreateRequestScreen
- Тап на ожидающую заявку → _OffersScreen (список офферов)

### Таб "Попутки"
- Выбор маршрута + поиск готовых поездок водителей
- Тап "Забронировать" → _BookingFormScreen

### Форма заявки (_CreateRequestScreen) и бронирования (_BookingFormScreen)
- Маршрут (dropdown), дата/время (_DateTimePicker), места, оплата (cash/card/kaspi)
- Адрес А (pickup_address + entrance)
- Доп. адреса подачи (_AddrPair, кнопка "+ добавить")
- Адрес Б (destination_address + destination_entrance)
- Доп. точки назначения (_AddrPair, кнопка "+ добавить")
- Для кого (себя / другого человека — contact_name, contact_phone)
- Комментарий

### Редактирование заявки (_EditRequestScreen)
- Те же поля, инициализируются из существующей заявки
- Кнопка "Отменить заявку" (DELETE)

### Принятие оффера (_OffersScreen)
- Bottom sheet подтверждения адреса перед accept
- POST /trip-requests/{id}/accept/{offer_id}

### Прочее
- История поездок (history_screen.dart)
- Профиль (profile_screen.dart) — ошибки загрузки теперь показываются в snackbar
- Поддержка, Настройки, О приложении (info_screens.dart)
  - Телефон кликабельный (tel:), WhatsApp и Telegram открывают мессенджеры
  - Форма → кнопка "Открыть в WhatsApp" с предзаполненным текстом
  - Контакты: константы `_supportPhone`, `_supportWhatsApp`, `_supportTelegram` в начале файла

## Структура файлов
```
zholaushy_passenger/lib/
├── main.dart                    # GoRouter: /login, /register, /home, /history
└── screens/
    ├── login_screen.dart        # OTP-вход
    ├── register_screen.dart     # регистрация → автологин
    ├── home_screen.dart         # ВСЯ логика (1 файл)
    │   ├── _AddrPair            # top-level класс
    │   ├── _TripsTab            # активные заявки и брони
    │   ├── _PoputkaTab          # поиск готовых поездок
    │   ├── _BookingFormScreen   # форма бронирования поездки
    │   ├── _CreateRequestScreen # форма создания заявки
    │   ├── _EditRequestScreen   # редактирование заявки
    │   ├── _OffersScreen        # офферы от водителей
    │   ├── _OfferCard           # карточка одного оффера
    │   └── _DateTimePicker      # кастомный пикер даты/времени
    ├── history_screen.dart
    ├── profile_screen.dart
    └── info_screens.dart
```

## Что сделать дальше (план)
- [ ] Экран активной поездки: пассажир принял оффер → показать данные водителя, кнопку "Отменить"
- [ ] Push-уведомления: колокольчик в AppBar, показывать когда водитель откликнулся
- [ ] История: тап на поездку → детали (маршрут, водитель, адреса, цена)
- [ ] Pull-to-refresh на экране офферов
- [ ] Рейтинг водителя после завершения поездки
