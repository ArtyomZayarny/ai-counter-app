# Demo Mode Plan — Ytilities App Store Review

## Problem

Apple rejected Ytilities twice because reviewers can't test meter recognition without a real meter.

### Apple Review Messages

**March 12, 2026:**
> The AI failed to verify the electricity meters, which resulted in an error message being displayed. To resolve this issue, it would be appropriate to provide a demo meter reading to verify all the features.

**March 24, 2026 (Guideline 2.1):**
> Unable to verify the utility bill using the camera, as it displayed an error message.
> Still need a demo reading to showcase all the features of the app.
>
> Review Device: iPad Air 11-inch (M3) and iPhone 17 Pro Max, iOS 26.3.1
> Version reviewed: 1.2.0

## Solution

Add "Try Demo" button to authenticated `ScanScreen` that sends a bundled meter photo through the **real** `/recognize` API. No backend changes — real GPT-4o recognition, real reading saved, appears on dashboard.

Guest mode already has this pattern (`guest_scan_screen.dart` → `_tryDemo()`). We replicate it for authenticated users.

## Implementation

### Files to Change

| File | Change |
|------|--------|
| `ai-counter-app/lib/api_service.dart` | Add `recognizeMeterFromBytes()` — authenticated version of `guestRecognizeMeterFromBytes` |
| `ai-counter-app/lib/scan_screen.dart` | Add `utilityType` param, `_tryDemo()` method, demo button in preview + error screens |
| `ai-counter-app/lib/home_screen.dart` | Pass `utilityType: meter.utilityType` to ScanScreen (1 line, line 314) |
| `ai-counter-app/pubspec.yaml` | Register new demo assets |
| `ai-counter-app/assets/demo_gas_meter.jpg` | **NEW** — photo of real gas meter |
| `ai-counter-app/assets/demo_water_meter.jpg` | **NEW** — photo of real water meter |

### Step 1: Demo Photos

Take photos of real gas and water meters (JPEG, clear focus on digits, ~960x1280). Place in `ai-counter-app/assets/`. Electricity photo already exists (`demo_electricity_meter.jpg`).

Register in `pubspec.yaml`:
```yaml
assets:
  - assets/demo_electricity_meter.jpg
  - assets/demo_gas_meter.jpg
  - assets/demo_water_meter.jpg
```

### Step 2: `api_service.dart` — Add Authenticated Demo Function

After `recognizeMeter()` (line 70), add `recognizeMeterFromBytes()`:
- Same as `guestRecognizeMeterFromBytes` but targets `/recognize` with JWT auth
- Takes `Uint8List bytes` + `String meterId`
- Returns `{result, reading_id}` — reading is auto-saved by backend

### Step 3: `scan_screen.dart` — Add Demo Capability

1. Add `utilityType` parameter (default: `'gas'`)
2. Add demo asset map:
   ```dart
   const _demoAssets = {
     'gas': 'assets/demo_gas_meter.jpg',
     'water': 'assets/demo_water_meter.jpg',
     'electricity': 'assets/demo_electricity_meter.jpg',
   };
   ```
3. Add `_tryDemo()` method: load asset → `recognizeMeterFromBytes()` → show result
4. Add sparkle icon button next to camera button in `_buildPreview()`
5. Add "Try with Sample Photo" button in `_buildError()` — critical for when camera doesn't init on iPad

### Step 4: `home_screen.dart` — Pass Utility Type

Line 314, change:
```dart
ScanScreen(meterId: meter.id, meterLabel: label)
```
to:
```dart
ScanScreen(meterId: meter.id, meterLabel: label, utilityType: meter.utilityType)
```

### Step 5: App Store Connect Review Notes

```
DEMO MODE: Tap the sparkle icon next to the camera button to test with a
built-in sample meter photo. Works on all 3 tabs (Gas/Water/Electricity).
If camera doesn't initialize, the error screen has "Try with Sample Photo".
```

## Verification Checklist

- [ ] `flutter analyze` — zero warnings
- [ ] `flutter test` — all tests pass
- [ ] iOS device: each tab → camera → sparkle icon → recognition → "Saved!" → appears on dashboard
- [ ] Force camera error → "Try with Sample Photo" works
- [ ] `flutter build ipa --release` — successful build
- [ ] Upload via Transporter → submit for review with updated Review Notes

## Risk Assessment

**Low risk.** Reuses proven pattern from guest mode. Demo images go through real API — no mocking, no special cases. Only new code: asset loading + `recognizeMeterFromBytes()` (adaptation of existing function).

**Edge case:** Multiple demo runs create duplicate readings. This is harmless and actually proves the app works.

**Edge case:** Railway cold start on first call (15-30s). Health check on HomeScreen keeps server warm.
