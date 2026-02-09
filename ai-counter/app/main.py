import asyncio
import json
import time

from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse

from app.recognizer import recognize_digits
from app.storage import save_image
from app.validation import (
    ValidationError,
    normalize_digits,
    validate_digit_count,
    validate_image,
)

app = FastAPI(title="AI Counter", version="1.2")

TIMEOUT_SECONDS = 10


@app.post("/recognize")
async def recognize(image: UploadFile = File(...)):
    # 1. Validate input
    try:
        image_data = await validate_image(image)
    except ValidationError as e:
        return JSONResponse(status_code=400, content={"error": e.detail})

    # 2. Start timer
    start = time.monotonic()

    # 3. Call GPT-4o Vision API with timeout
    try:
        raw_text = await asyncio.wait_for(
            asyncio.to_thread(recognize_digits, image_data, image.content_type),
            timeout=TIMEOUT_SECONDS - (time.monotonic() - start),
        )
    except asyncio.TimeoutError:
        return JSONResponse(
            status_code=408, content={"error": "Processing exceeded 10 seconds"}
        )
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})

    # 4. Parse structured JSON response, fallback to plain-text normalization
    try:
        data = json.loads(raw_text)
        digits = "".join(str(data[f"pos{i}"]) for i in range(1, 6))
    except (json.JSONDecodeError, KeyError, TypeError):
        digits = normalize_digits(raw_text)

    if len(digits) < 5:
        return JSONResponse(
            status_code=422,
            content={"error": f"Expected at least 5 digits, got {len(digits)}", "result": digits},
        )
    digits = digits[:5]

    # 5. Persist original image
    save_image(image_data)

    # 6. Return result
    return {"result": digits}
