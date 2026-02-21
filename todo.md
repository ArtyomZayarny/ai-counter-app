# TODO — Ytilities

**Updated:** February 16, 2026

---

## Done (MVP v1.0)

- [x] Backend: FastAPI + PostgreSQL + async SQLAlchemy
- [x] GPT-4o Vision API integration for OCR
- [x] Gas meter recognition (5 digits, mechanical drums)
- [x] Water meter recognition (5 digits, rotating drums)
- [x] Electricity meter recognition (6 digits, LCD/LED)
- [x] Auth: email/password registration + login (JWT)
- [x] Auth: Google OAuth integration
- [x] Auto-create property + gas meter on registration
- [x] On-demand water/electricity meter creation
- [x] Readings CRUD with ownership checks
- [x] Tariff management (create, update, list)
- [x] Bill calculator (2 readings + tariff → cost)
- [x] Bills CRUD
- [x] Flutter: splash screen, gradient UI, Material 3
- [x] Flutter: three-tab dashboard (Gas / Water / Light)
- [x] Flutter: camera scanning with review flow
- [x] Flutter: reading cards + bill cards with delete
- [x] Flutter: server health check indicator
- [x] Multi-tap guards on all API buttons
- [x] Friendly error messages (no raw exceptions)
- [x] Production URL default in config.dart
- [x] Deploy backend to Railway
- [x] Backend tests (24) + Flutter tests (4)
- [x] iOS Local Network permissions (Info.plist)
- [x] iOS App Store preparation (bundle ID, provisioning, privacy policy)
- [x] TestFlight build and distribution
- [x] Google Sign-In (iOS + backend)
- [x] Manual meter reading input (backend POST /readings + Flutter bottom sheet UI)
- [x] No-internet toast notification (connectivity_plus + friendly error messages)
- [x] Branding fix: Google OAuth consent screen renamed to Ytilities
- [x] Build release APK v1.1.0+3
- [x] Build iOS IPA v1.1.0+3, uploaded to App Store Connect

---

## Must Do (blocking release)

- [ ] **End-to-end QA with real meter photos** — test all 3 meter types on device, verify digit accuracy
- [ ] **PRD v2.0** — update prd.md to reflect multi-meter scope, auth, billing (currently gas-only v1.2)

---

## Should Do (before user testing)

- [ ] **Bug: comma decimal in tariff breaks calculation** — entering tariff price with comma separator (e.g. "3,2" instead of "3.2") causes calculation to fail; need to normalize comma → dot before parsing
- [ ] **Scan fallback → manual input** — when recognition API fails, error screen offers "Enter Manually" button that opens the manual input sheet
- [ ] **Camera permission handling** — graceful dialog when iOS/Android denies camera access
- [ ] **Photo gallery fallback** — allow selecting existing photos, not just camera capture
- [ ] **Empty state UX** — better messaging when no readings/bills exist yet
- [ ] **Widget tests** — Flutter UI tests for key screens

---

## Nice to Have (post-MVP)

- [ ] **Reading history chart** — visualize consumption over time
- [ ] **Push notifications** — remind users to submit monthly readings
- [ ] **Multi-language** — localization (currently English only)
- [ ] **Multi-property** — support multiple addresses per user
- [ ] **Export data** — CSV/PDF export of readings and bills
- [ ] **Confidence scores** — expose GPT-4o confidence for recognized digits
- [ ] **Retry logic** — exponential backoff for API timeouts
- [ ] **Rate limiting** — protect API from abuse at scale
- [ ] **Analytics** — track recognition success rate, API latency
- [ ] **Dark mode** — support system dark mode preference
- [ ] **Migration to Cloud Vision** — when costs exceed ~$200/month (see tech-finance-solution.md)
