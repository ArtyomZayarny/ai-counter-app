# Ytilities

Utility meter reading platform — scan your gas, water, and electricity meters with AI, track consumption, and calculate bills.

## Architecture

| Component | Stack | Location |
|-----------|-------|----------|
| Backend | Python FastAPI + PostgreSQL + GPT-4o Vision API | `ai-counter/` |
| Mobile App | Flutter (iOS + Android) | `ai-counter-app/` |
| Database | PostgreSQL (async SQLAlchemy + Alembic) | Railway |

## Features

- **AI Meter Recognition** — take a photo of your meter, GPT-4o Vision extracts the digits
- **Manual Input** — enter readings manually via numeric keypad
- **3 Meter Types** — gas, water, electricity with dedicated OCR prompts
- **Bill Calculator** — select two readings + tariff to compute cost
- **Auth** — email/password + Google Sign-In (JWT-based)
- **Offline Detection** — toast notification when internet is unavailable
- **Auto-save** — readings are saved immediately after recognition

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/auth/register` | Register new user |
| POST | `/auth/login` | Login with email/password |
| POST | `/auth/google` | Google OAuth login |
| POST | `/recognize` | Upload image for AI recognition (auto-saves reading) |
| POST | `/readings` | Create reading manually |
| GET | `/readings` | List readings for a meter |
| DELETE | `/readings/{id}` | Delete a reading |
| GET | `/meters` | List user's meters |
| POST | `/meters` | Create a new meter |
| GET | `/tariffs` | List tariffs |
| POST | `/tariffs` | Create tariff |
| GET | `/bills` | List bills |
| POST | `/bills` | Calculate and save bill |
| DELETE | `/bills/{id}` | Delete a bill |
| GET | `/health` | Health check |

## Quick Start

### Backend

```bash
cd ai-counter
pip install -r requirements.txt

# Required env vars: DATABASE_URL, JWT_SECRET, OPENAI_API_KEY, GOOGLE_CLIENT_ID
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Flutter App

```bash
cd ai-counter-app
flutter pub get
flutter run                    # Android emulator
flutter run --release          # iPhone (release mode required for iOS)
```

### Build Release

```bash
cd ai-counter-app
flutter build apk --release    # Android APK
flutter build ipa --release    # iOS IPA (requires Xcode signing)
```

## Database

PostgreSQL with 6 tables (all UUIDs):

- **users** — accounts with hashed passwords
- **properties** — addresses linked to users
- **meters** — gas/water/electricity meters per property
- **readings** — meter values with timestamps
- **tariffs** — price per unit with effective dates
- **bills** — calculated costs from reading pairs

## Deployment

- **Backend**: Railway (PostgreSQL + FastAPI)
- **iOS**: App Store Connect via TestFlight
- **Android**: APK distribution
- **Production API**: `https://ai-counter-app-production.up.railway.app`

## Release History

| Version | Date | Changes |
|---------|------|---------|
| 1.1.0+3 | Feb 16, 2026 | Manual meter input, no-internet toast, branding fix |
| 1.0.0+2 | Feb 14, 2026 | iOS App Store prep, Google Sign-In, privacy policy |
| 1.0.0+1 | Feb 13, 2026 | MVP: 3 meter types, auth, billing, camera scanning |

## Documentation

- `@docs/prd.md` — Product Requirements Document
- `@docs/tech-finance-solution.md` — GPT-4o vs Tesseract analysis
- `@docs/mvp-v1.0.md` — MVP specification
- `progress.md` — Development progress log
- `todo.md` — Task tracker
