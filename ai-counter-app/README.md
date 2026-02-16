# Ytilities — Flutter Client

Cross-platform mobile app for utility meter reading with AI recognition.

## Setup

```bash
flutter pub get
flutter run              # Android
flutter run --release    # iOS (release mode required)
```

## Project Structure

```
lib/
  main.dart              # App entry, Provider setup, AuthGate
  config.dart            # API base URL (production default)
  api_service.dart       # HTTP client, all REST methods
  home_screen.dart       # Three-tab dashboard + FABs
  scan_screen.dart       # Camera → recognize → save
  models/                # Data classes (User, Meter, Reading, Tariff, Bill)
  providers/             # AuthProvider, DashboardProvider
  screens/
    auth/                # Login, Register
    calculator_screen.dart
    dashboard_screen.dart
  services/              # Auth service, secure storage
  widgets/               # ReadingCard, BillCard, AppLogo, CustomLoader
```

## Dependencies

- `camera` — camera access for meter scanning
- `http` — REST API communication
- `provider` — state management
- `flutter_secure_storage` — JWT token persistence
- `google_sign_in` — Google OAuth
- `connectivity_plus` — network status monitoring
- `intl` — date formatting

## Build

```bash
flutter build apk --release    # Android (outputs to build/app/outputs/flutter-apk/)
flutter build ipa --release    # iOS (outputs to build/ios/ipa/)
```

Local dev override: `flutter run --dart-define=API_URL=http://localhost:8000`
