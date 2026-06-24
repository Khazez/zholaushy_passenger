# ZHOLAUSHY — Project Context for Claude

## Что это за проект

Мобильная платформа для заказа межгородских поездок (аналог Яндекс.Межгород / InDriver).
Запуск: западный Казахстан, город Актобе.
Название: **ZHOLAUSHY** (может измениться).

## Роли пользователей

- **passenger** — пассажир
- **driver** — водитель
- **fleet** — таксопарк (может добавлять водителей под собой)
- **admin** — диспетчер / администратор

## Стек технологий

| Слой | Технология |
|------|-----------|
| Мобильное приложение | Flutter (iOS + Android) |
| Веб-панель (диспетчер) | Next.js / React |
| Бэкенд API | FastAPI (Python) |
| База данных | PostgreSQL |
| Кэш / real-time | Redis |
| Хранилище файлов | MinIO |
| Аутентификация | JWT (access + refresh tokens) |
| Push-уведомления | Firebase Cloud Messaging |

## Архитектура

```
Flutter (Пассажир)   Flutter (Водитель)   Next.js (Диспетчер)
        └──────────────────┬──────────────────────┘
                      REST API + WebSocket
                           │
                    FastAPI Backend
               ┌───────────┼────────────┐
           PostgreSQL     Redis        MinIO
           (основная БД)  (кэш,сессии) (файлы)
```

## Бизнес-логика (два режима для пассажира и водителя)

### Режим 1 — Попутки (InDriver-стиль):
- Пассажир создаёт заявку: откуда → куда, дата, кол-во мест
- Водители видят заявки и откликаются с ценой (TripOffer)
- Пассажир выбирает водителя → поездка подтверждена

### Режим 2 — Готовые поездки:
- Водитель создаёт поездку: маршрут, дата, цена, места
- Пассажир видит список и бронирует место (Booking)

### Пассажир (полный флоу):
1. Регистрируется (POST /api/v1/auth/register → {name, phone, password})
2. Логинится (POST /api/v1/auth/login → {phone, password} → access_token)
3. Видит два таба: "Попутки" и "Поездки"
4. Создаёт заявку или бронирует готовую поездку
5. Оплачивает (Kaspi / карта / наличные)
6. Получает push-уведомление
7. Если отменяет за < 1 часа — штраф (% из PlatformSettings)

### Водитель:
1. Регистрируется → загружает документы → верификация у admin
2. Создаёт поездку (Trip) или откликается на заявки пассажиров (TripOffer)
3. Отмечает поездку завершённой
4. Получает рейтинг

### Диспетчер (веб-панель):
1. Входит по email + пароль (POST /api/v1/auth/admin/login?email=...&password=...)
2. Верифицирует водителей
3. Управляет маршрутами и ценами
4. Управляет настройками платформы

## Важные технические детали

- **bcrypt**: используем `import bcrypt` напрямую, НЕ через passlib
- **Async**: create_async_engine + AsyncSession + asyncpg
- **JWT**: python-jose, алгоритм HS256
- **Venv активация**: venv\Scripts\activate (cmd, не PowerShell)
- **CORS**: allow_origins=["*"], allow_credentials=False в main.py
- **settings.py**: current_user — dict, проверять через current_user.get("role")
- **database.py**: НЕ класть seed-скрипты сюда — только движок и get_db
- **register endpoint**: возвращает {"message": "Пользователь создан"} — НЕ токен!
  После регистрации нужно отдельно вызвать /auth/login чтобы получить токен.
- **trip-requests**: эндпоинт пишется через ДЕФИС: /api/v1/trip-requests/ (не trip_requests)
- **Flutter Web**: использовать dart:html window.localStorage вместо shared_preferences
  (shared_preferences вызывает MissingPluginException на Flutter Web)
- **Dio на Flutter Web**: всегда указывать явно Content-Type: application/json в Options

## API эндпоинты (проверено в Swagger)

### Auth
- POST /api/v1/auth/register — {name, phone, password} → {"message": "Пользователь создан"}
- POST /api/v1/auth/login — {phone, password} → {"access_token": "..."}
- POST /api/v1/auth/admin/login?email=...&password=... → {"access_token": "..."}

### Routes
- GET /api/v1/routes/ — список маршрутов
- POST /api/v1/routes/ — создать маршрут (admin)

### Trips
- GET /api/v1/trips/ — список поездок (требует auth, возможно query params)
- POST /api/v1/trips/ — создать поездку (driver)

### Trip Requests (InDriver-стиль) — ДЕФИС!
- POST /api/v1/trip-requests/ — создать заявку пассажира
- GET /api/v1/trip-requests/ — получить открытые заявки
- POST /api/v1/trip-requests/offers — водитель откликается
- GET /api/v1/trip-requests/{request_id}/offers — офферы на заявку
- POST /api/v1/trip-requests/{request_id}/accept/{offer_id} — принять оффер

### Bookings
- POST /api/v1/bookings/ — забронировать место в поездке
- DELETE /api/v1/bookings/{booking_id} — отменить бронь

### Drivers
- GET /api/v1/drivers/unverified — неверифицированные водители
- PATCH /api/v1/drivers/{id}/verify — верифицировать
- PATCH /api/v1/drivers/{id}/reject — отклонить

### Admin
- GET /api/v1/admin/stats — статистика
- GET /api/v1/admin/trips — все поездки

### Settings
- GET /api/v1/settings/ — настройки платформы
- PATCH /api/v1/settings/{key} — изменить настройку

## Переменные окружения (.env)

```
DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5432/mezhgorod
REDIS_URL=redis://localhost:6379
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=...
MINIO_SECRET_KEY=...
JWT_SECRET_KEY=...
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=30
FIREBASE_CREDENTIALS_PATH=./firebase-key.json
CANCELLATION_FEE_PERCENT=20
```

## Адресная модель (важно!)

extra_pickups и extra_destinations — это списки объектов `{address: str, entrance: str?}`.
В Flutter используется класс `_AddrPair` (два TextEditingController: address + entrance).
НЕ хранить как plain strings — бэкенд ожидает объекты.

## Текущий статус

### Flutter — пассажир (zholaushy_passenger) ✅
- [x] GoRouter, dart:html localStorage, token = 'token'
- [x] Login/Register с OTP
- [x] Таб Поездки: активные заявки, принятые заявки (с данными водителя), брони
- [x] Таб Попутки: поиск поездок водителей по маршруту, бронирование
- [x] Создать заявку: маршрут, дата/время (DateTimePicker), места, оплата, для кого
- [x] Адрес А + подъезд, доп. адреса подачи (+ кнопка добавить)
- [x] Адрес Б + подъезд, доп. точки назначения (+ кнопка добавить)
- [x] Редактировать заявку (patch), отменить заявку
- [x] Экран офферов: принять водителя через bottom sheet подтверждения адреса
- [x] История поездок, профиль, поддержка, настройки, о приложении
- [x] _AddrPair класс: пара контроллеров для каждого доп. адреса

### Бэкенд (taxi-backend) ✅
- token-ключ пассажира: localStorage['token']
- extra_pickups/extra_destinations → list of `{address, entrance?}` objects
- trip-requests через ДЕФИС: /api/v1/trip-requests/

## Структура файлов

```
zholaushy_passenger/lib/
├── main.dart                    # GoRouter: /login, /register, /home, /history
└── screens/
    ├── login_screen.dart        # OTP-вход
    ├── register_screen.dart     # регистрация
    ├── home_screen.dart         # ВСЯ логика: табы, формы, офферы
    │   ├── _AddrPair            # класс: пара контроллеров (address + entrance)
    │   ├── _TripsTab            # активные заявки и брони
    │   ├── _PoputkaTab          # поиск готовых поездок
    │   ├── _BookingFormScreen   # форма бронирования поездки
    │   ├── _CreateRequestScreen # форма создания заявки
    │   ├── _EditRequestScreen   # редактирование заявки
    │   └── _OffersScreen        # список офферов от водителей
    ├── history_screen.dart      # история поездок
    ├── profile_screen.dart      # профиль пользователя
    └── info_screens.dart        # Поддержка, Настройки, О приложении
```

## Как использовать этот файл

При каждом новом чате с Claude — прикрепляй этот файл.
Это даёт Claude полный контекст без повторных объяснений.
