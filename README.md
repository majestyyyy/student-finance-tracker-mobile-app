# Student Finance Tracker — Phase 1

Separated architecture for a student-focused personal finance app:

| Layer | Stack |
|-------|-------|
| Mobile | Flutter (`mobile/`) |
| API | Dart Frog on port `8080` (`backend/`) |
| Database | PostgreSQL 3NF (`database/`) |
| Identity | Microsoft Entra External ID (Azure AD B2C) |

## Phase 1 Scope

- Account creation & Azure OIDC sign-in
- User sync (`POST /v1/users/sync`)
- Wallet initialization (`POST /v1/wallets/create`)
- Dashboard UI prototype with placeholder data

---

## Quick Start (Local Debugging)

### 1. Start PostgreSQL

```bash
docker compose up -d
```

Schema and seed data load automatically from `database/schema.sql` and `database/seeds.sql`.

### 2. Start the API

```bash
cd backend
dart pub get
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=tracker
export DB_USER=tracker
export DB_PASSWORD=tracker_dev_password
dart_frog dev --port 8080
```

Health check: `http://localhost:8080/`

### 3. Run the Flutter app

**Dashboard UI preview (no Azure required):**

```bash
cd mobile
flutter pub get
flutter run --dart-define=PREVIEW_DASHBOARD=true
```

**Full auth flow (configure Azure first — see below):**

```bash
# iOS Simulator
flutter run \
  --dart-define=APP_ENV=local \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=AZURE_TENANT_NAME=your-tenant \
  --dart-define=AZURE_TENANT_ID=your-tenant-id \
  --dart-define=AZURE_CLIENT_ID=your-client-id

# Android Emulator
flutter run \
  --dart-define=APP_ENV=local \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=AZURE_TENANT_NAME=your-tenant \
  --dart-define=AZURE_TENANT_ID=your-tenant-id \
  --dart-define=AZURE_CLIENT_ID=your-client-id
```

---

## API Endpoints

### `POST /v1/users/sync`

Upserts a user by `azure_user_id`.

```json
{
  "azure_user_id": "b2c-object-id-from-sub-claim",
  "email": "student@university.edu",
  "display_name": "Alex Student"
}
```

### `POST /v1/wallets/create`

Creates a wallet after resolving the internal user `id`.

```json
{
  "azure_user_id": "b2c-object-id-from-sub-claim",
  "account_type": "cash",
  "name": "Campus Cash",
  "balance": 84.50,
  "currency_code": "USD"
}
```

Valid `account_type` values: `cash`, `traditional_bank`, `digital_bank`, `credit_card`, `bnpl`, `savings`.

---

## Azure Entra External ID Setup

1. Register a mobile/native app in your B2C tenant.
2. Add redirect URI: `com.studenttracker.app://oauthredirect`
3. Enable PKCE and assign the sign-up/sign-in user flow (`B2C_1_signupsignin` by default).
4. Pass tenant values via `--dart-define` (see `mobile/lib/config/azure_config.dart`).

After sign-in, `AuthService` extracts the `sub` claim and email from the ID token, then POSTs to `/v1/users/sync`.

---

## Project Layout

```
TRACKER/
├── database/
│   ├── schema.sql          # 3NF DDL (users, account_types, accounts)
│   └── seeds.sql           # account_types seed data
├── backend/
│   ├── routes/
│   │   ├── _middleware.dart
│   │   └── v1/
│   │       ├── users/sync.dart
│   │       └── wallets/create.dart
│   └── lib/
│       ├── database/
│       ├── models/
│       └── validation/
├── mobile/
│   └── lib/
│       ├── config/
│       ├── services/
│       ├── widgets/
│       └── views/
└── docker-compose.yml
```
