import asyncio
import json
import re
import time

from fastapi import APIRouter, File, Form, Request, UploadFile
from fastapi.responses import JSONResponse
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.recognizer import recognize_digits
from app.validation import ValidationError, normalize_digits, validate_image

router = APIRouter(prefix="/guest", tags=["guest"])

limiter = Limiter(key_func=get_remote_address)

TIMEOUT_SECONDS = 10

VALID_UTILITY_TYPES = {"gas", "water", "electricity"}

# Default digit counts per utility type (no meter DB record for guests)
_DEFAULT_DIGITS = {"gas": 5, "electricity": 6, "water": 5}


def _parse_response(raw_text: str, digit_count: int = 5) -> str:
    """Extract digits from GPT-4o response (JSON or chain-of-thought)."""
    match = re.search(r'\{[^}]+\}', raw_text)
    if match:
        try:
            data = json.loads(match.group())
            values = [data.get(f"pos{i}") for i in range(1, digit_count + 1)]
            if all(v is not None and isinstance(v, int) and 0 <= v <= 9 for v in values):
                return "".join(str(v) for v in values)
        except (json.JSONDecodeError, TypeError):
            pass
    return normalize_digits(raw_text)


@router.post("/recognize")
@limiter.limit("5/minute")
async def guest_recognize(
    request: Request,
    image: UploadFile = File(...),
    utility_type: str = Form("gas"),
):
    # Validate utility type
    utility_type = utility_type.strip().lower()
    if utility_type not in VALID_UTILITY_TYPES:
        return JSONResponse(
            status_code=400,
            content={"error": f"Invalid utility_type. Must be one of: {', '.join(sorted(VALID_UTILITY_TYPES))}"},
        )

    # Validate image
    try:
        image_data = await validate_image(image)
    except ValidationError as e:
        return JSONResponse(status_code=400, content={"error": e.detail})

    # Call GPT-4o Vision API with timeout
    start = time.monotonic()
    try:
        raw_text = await asyncio.wait_for(
            asyncio.to_thread(recognize_digits, image_data, image.content_type, utility_type),
            timeout=TIMEOUT_SECONDS - (time.monotonic() - start),
        )
    except asyncio.TimeoutError:
        return JSONResponse(status_code=408, content={"error": "Processing exceeded 10 seconds"})
    except Exception:
        return JSONResponse(status_code=500, content={"error": "Recognition failed"})

    # Parse response
    expected = _DEFAULT_DIGITS.get(utility_type, 5)
    digits = _parse_response(raw_text, expected)

    if len(digits) < expected:
        return JSONResponse(
            status_code=422,
            content={"error": f"Expected at least {expected} digits, got {len(digits)}", "result": digits},
        )
    digits = digits[:expected]

    return {"result": digits}
