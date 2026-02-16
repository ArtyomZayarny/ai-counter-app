# Progress — February 16, 2026

## Backend (ai-counter/)

Full Python FastAPI backend with PostgreSQL, auth, multi-meter OCR, and billing:

### Core
- **app/main.py** — FastAPI app, CORS middleware, router includes, `/health` endpoint
- **app/config.py** — Settings from env vars (DATABASE_URL, JWT_SECRET, OPENAI_API_KEY, GOOGLE_CLIENT_ID)
- **app/database.py** — Async SQLAlchemy engine with connection pooling (5 pool / 10 overflow / pre-ping)
- **app/dependencies.py** — `get_db()` and `get_current_user()` dependency injection

### Authentication
- **app/routers/auth.py** — Register, login, Google OAuth endpoints; auto-creates property + gas meter for new users
- **app/services/auth.py** — JWT encode/decode, bcrypt hashing, Google token verification

### Recognition
- **app/recognizer.py** — GPT-4o Vision API with per-meter-type prompts (gas/water/electricity)
- **app/validation.py** — JPEG/PNG validation via binary headers, digit normalization, dimension checks

### Data Layer
- **app/models/** — SQLAlchemy ORM models: User, Property, Meter, Reading, Tariff, Bill (all UUIDs)
- **app/schemas/** — Pydantic request/response schemas
- **app/routers/readings.py** — CRUD for readings with ownership checks + `/recognize` endpoint + `POST /readings` manual input
- **app/routers/meters.py** — Meter listing and creation (gas/water/electricity)
- **app/routers/tariffs.py** — Tariff CRUD with effective date tracking
- **app/routers/bills.py** — Bill calculation from reading pairs + tariff, CRUD
- **app/services/billing.py** — Consumption and cost computation

### Infrastructure
- **alembic/** — Database migrations
- **requirements.txt** — Pinned dependencies
- Deployed on Railway with PostgreSQL

### Tests (24 total)

| File | Count | Coverage |
|------|-------|----------|
| tests/test_recognizer.py | 12 | normalize_digits, validate_digit_count |
| tests/test_api.py | 5 | Integration tests with mocked OpenAI API |
| tests/test_validation.py | 5 | Image dimension parsing for JPEG/PNG |
| tests/test_storage.py | 2 | File persistence and UUID naming |

---

## Flutter Client (ai-counter-app/)

Full-featured mobile app with auth, multi-meter dashboard, camera scanning, and billing:

### Auth
- **lib/screens/auth/login_screen.dart** — Email/password + Google Sign-In with loading states
- **lib/screens/auth/register_screen.dart** — Registration with name, email, password
- **lib/services/auth_service.dart** — Token management, Google Sign-In flow
- **lib/services/secure_storage_service.dart** — JWT token persistence

### Navigation & Dashboard
- **lib/main.dart** — App entry, Provider setup, AuthGate, animated splash screen
- **lib/home_screen.dart** — Three-tab interface (Gas / Water / Light), server health check, on-demand meter creation, manual input bottom sheet, connectivity monitoring
- **lib/screens/dashboard_screen.dart** — Reading cards + bill cards list with stagger animations

### Scanning & Recognition
- **lib/scan_screen.dart** — Camera preview → capture → review → API call → result display, utility-type aware

### Connectivity
- **connectivity_plus** — Real-time network monitoring with floating SnackBar toast on disconnect

### Billing
- **lib/screens/calculator_screen.dart** — Select 2 readings + tariff → calculate and save bill

### State Management
- **lib/providers/auth_provider.dart** — AuthProvider (login, logout, checkAuth, Google OAuth)
- **lib/providers/dashboard_provider.dart** — DashboardProvider (readings, bills, tariffs per meter, friendly error messages)

### Widgets & UI
- **lib/widgets/reading_card.dart** — Reading display with delete
- **lib/widgets/bill_card.dart** — Bill display with consumption, cost, period
- **lib/widgets/app_logo.dart** — Branded logo widget
- **lib/widgets/custom_loader.dart** — Contextual loading spinner
- **lib/config.dart** — API base URL (production default, local override via dart-define)

### API Layer
- **lib/api_service.dart** — HTTP client with Bearer token, all REST methods (including manual createReading), 15s timeout, friendly errors

### Tests (4 total)
- **test/api_service_test.dart** — JSON parsing, error mapping, SocketException handling

---

## Documentation (@docs/)

- **prd.md** (v1.2) — Original API specification for gas meter recognition
- **tech-finance-solution.md** (v1.0) — GPT-4o selection rationale, cost analysis
- **mvp-v1.0.md** — Complete MVP state documentation (current)

---

## Key Milestones

| Date | Milestone |
|------|-----------|
| Feb 8 | Initial commit: backend + basic Flutter client (gas only) |
| Feb 8 | Railway deployment, Android fixes |
| Feb 9 | Auth system, dashboard, billing, UI redesign |
| Feb 10 | UI polish: gradient theme, splash screen, loader |
| Feb 11 | Electricity meter support, multi-tap guards, branded UI, DB pool fix |
| Feb 12 | Production URL fix, friendly error messages, water meter OCR |
| Feb 13 | MVP v1.0 documentation freeze |
| Feb 14 | iOS App Store preparation, TestFlight build 1.0.0+2, privacy policy, Google Sign-In |
| Feb 16 | Manual meter input, no-internet toast, branding fix, v1.1.0+3 release (iOS + Android) |
