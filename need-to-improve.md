# Security & Bug Fixes — Ready to Implement

Validated against actual code on 2026-02-16. All line numbers confirmed.

> **Status: ALL DONE** — All phases implemented and deployed (2026-02-21).

---

## Phase 1: CRITICAL ✅

### 1.1 Remove default JWT secret ✅
**File:** `ai-counter/app/config.py:17`
```python
# BEFORE
JWT_SECRET = os.environ.get("JWT_SECRET", "dev-secret-change-me")
GOOGLE_CLIENT_ID = os.environ.get("GOOGLE_CLIENT_ID", "")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")

# AFTER
JWT_SECRET = os.environ["JWT_SECRET"]
GOOGLE_CLIENT_ID = os.environ["GOOGLE_CLIENT_ID"]
OPENAI_API_KEY = os.environ["OPENAI_API_KEY"]
```

### 1.2 Hide error details from client ✅
**File:** `ai-counter/app/routers/readings.py:85`
```python
# BEFORE
return JSONResponse(status_code=500, content={"error": str(e)})
# AFTER
return JSONResponse(status_code=500, content={"error": "Recognition failed"})
```

**File:** `ai-counter/app/routers/auth.py:82-91` — remove ALL debug logging + hide Google error
```python
# DELETE lines 82-85 (logger setup + token length + GOOGLE_CLIENT_ID leak)
# DELETE line 88 (sub/email PII leak)
# Line 91: change detail=f"Invalid Google token: {e}" -> detail="Invalid Google token"
```

### 1.3 Password validation ✅
**File:** `ai-counter/app/schemas/auth.py`
```python
# Add Field to import
from pydantic import BaseModel, EmailStr, Field

# RegisterRequest
password: str = Field(min_length=8)

# LoginRequest
password: str = Field(min_length=1)
```

---

## Phase 2: HIGH — Input Validation ✅

### 2.1 Tariff price validation ✅
**File:** `ai-counter/app/schemas/tariff.py`
```python
from pydantic import BaseModel, Field  # add Field import

class TariffCreate(BaseModel):
    price_per_unit: float = Field(gt=0)  # was: float

class TariffUpdate(BaseModel):
    price_per_unit: float | None = Field(None, gt=0)  # was: float | None = None
```

### 2.2 Bill validation ✅
**File:** `ai-counter/app/schemas/bill.py`
```python
from pydantic import BaseModel, Field  # add Field import

class BillCreate(BaseModel):
    tariff_per_unit: float = Field(gt=0)  # was: float
```

**File:** `ai-counter/app/routers/bills.py:80-101`
```python
# After parsing from_id and to_id, ADD:
if from_id == to_id:
    raise HTTPException(status_code=400, detail="From and to readings must be different")

# Change line 100:
if consumed <= 0:  # was: consumed < 0
```

### 2.3 Query parameter bounds ✅
**File:** `ai-counter/app/routers/readings.py:148-150`
```python
from fastapi import ..., Query  # add Query to imports

limit: int = Query(default=50, ge=1, le=500),   # was: limit: int = 50
offset: int = Query(default=0, ge=0),            # was: offset: int = 0
```

**File:** `ai-counter/app/routers/bills.py:37-39`
```python
from fastapi import ..., Query  # add Query to imports

limit: int = Query(default=50, ge=1, le=500),
offset: int = Query(default=0, ge=0),
```

---

## Phase 3: MEDIUM — Security Hardening ✅

### 3.1 Rate limiting (slowapi) ✅
**File:** `ai-counter/requirements.txt` — add `slowapi>=0.1.9`

**File:** `ai-counter/app/main.py`
```python
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
```

Rate limits to apply:
- `/auth/login`, `/auth/register`, `/auth/google` — `10/minute`
- `/recognize` — `20/minute`
- `POST /readings`, `POST /bills` — `30/minute`

> Note: Each rate-limited endpoint needs `request: Request` parameter added.

### 3.2 Tighten CORS ✅
**File:** `ai-counter/app/main.py:19-25`
```python
# BEFORE
allow_methods=["*"],
allow_headers=["*"],

# AFTER
allow_methods=["GET", "POST", "PUT", "DELETE"],
allow_headers=["Authorization", "Content-Type"],
```

### 3.3 Backend .gitignore ✅
**File:** `ai-counter/.gitignore` (NEW)
```
.env
__pycache__/
*.pyc
.pytest_cache/
```

---

## Phase 4: Flutter Client ✅

### 4.1 Hide raw exceptions ✅
**File:** `ai-counter-app/lib/scan_screen.dart:117`
```dart
// BEFORE
_error = 'Unexpected error: $e';
// AFTER
_error = 'Something went wrong. Please try again';
```

### 4.2 Manual input max value ✅
**File:** `ai-counter-app/lib/home_screen.dart` (`_ManualInputSheetState._save`)
```dart
// After: if (value == null || value < 0)
// ADD:
if (value > 9999999) {
  setState(() => _error = 'Value is too large');
  return;
}
```

### 4.3 Clear password from memory ✅
**File:** `ai-counter-app/lib/screens/auth/login_screen.dart:52`
```dart
// Before _goHome(), ADD:
_passwordController.clear();
```

**File:** `ai-counter-app/lib/screens/auth/register_screen.dart:42`
```dart
// Before Navigator.pop(context), ADD:
_passwordController.clear();
```

---

## Commit Plan

1. `Fix critical security: JWT secret, error leakage, password validation`
2. `Add input validation: tariffs, bills, query limits`
3. `Add rate limiting with slowapi`
4. `Fix Flutter: hide exceptions, validate input, clear passwords`
5. Push + Railway auto-deploy
6. Bump version → 1.2.0+4, build iOS + Android

## Verification Checklist

- [x] `cd ai-counter && python -m pytest tests/` — all pass
- [x] `cd ai-counter-app && flutter analyze` — no errors
- [x] Register with password < 8 chars → 422
- [x] Create tariff with price_per_unit=-1 → 422
- [x] GET /readings?limit=999999 → capped at 500
- [x] /recognize error response has no stack trace
- [x] Create bill with same from/to reading → 400
- [x] Create bill with zero consumption → 400
- [x] Manual input > 9999999 → error shown
