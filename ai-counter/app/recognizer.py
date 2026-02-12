import base64
import logging
import os

from openai import OpenAI

logger = logging.getLogger(__name__)

OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")

SYSTEM_PROMPT = (
    "You are a precision gas meter digit reader.\n\n"
    "WHAT TO LOOK FOR:\n"
    "Find the horizontal row of MECHANICAL ROTATING DRUM WHEELS (rollers) in the center of the meter. "
    "These drums are inside a rectangular window and each drum shows a single digit (0-9) through the window slot. "
    "The drums have alternating digits visible above and below the main reading line.\n\n"
    "IGNORE EVERYTHING ELSE on the meter:\n"
    "- Serial numbers printed flat on the label\n"
    "- Year of manufacture, QR codes, barcodes\n"
    "- Technical specs (Qmax, Qmin, etc.)\n"
    "- Any text, brand names, or model numbers\n"
    "- Only read the MECHANICAL ROTATING DRUMS.\n\n"
    "COLOR RULES:\n"
    "- BLACK or WHITE background drums = INTEGER reading (left side). READ THESE.\n"
    "- RED background drums = decimal fraction (right side). COMPLETELY IGNORE red drums.\n\n"
    "READING RULES:\n"
    "1. Read exactly 5 black/white drums, strictly LEFT to RIGHT.\n"
    "2. Read the digit most centered in the viewing window for each drum.\n"
    "3. If a drum is between two digits (transitioning), report the LOWER digit.\n"
    "4. Leading zeros matter: 01814 stays 01814.\n"
    "5. Verify each drum independently before answering.\n\n"
    "RESPONSE FORMAT:\n"
    "Step 1: Describe what you see on each drum (left to right).\n"
    "Step 2: Return JSON: {\"pos1\": D, \"pos2\": D, \"pos3\": D, \"pos4\": D, \"pos5\": D} "
    "where D is a single integer 0-9."
)

USER_PROMPT = (
    "Look at the mechanical rotating drum wheels in the center of this gas meter. "
    "Ignore all printed text, serial numbers, and specs. "
    "Read only the 5 black/white drums left to right.\n\n"
    "Step 1: Describe what you see on each drum position.\n"
    "Step 2: Return the JSON with your reading."
)


def _detect_media_type(data: bytes) -> str:
    if data[:2] == b'\xff\xd8':
        return "image/jpeg"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    return "image/jpeg"


def recognize_digits(image_data: bytes, content_type: str) -> str:
    """Send image to GPT-4o Vision API and return raw response text."""
    b64 = base64.b64encode(image_data).decode("utf-8")
    media_type = _detect_media_type(image_data)

    logger.info("Sending image to GPT-4o: %d bytes, type=%s", len(image_data), media_type)

    client = OpenAI(api_key=OPENAI_API_KEY)

    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": USER_PROMPT},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:{media_type};base64,{b64}",
                            "detail": "high",
                        },
                    },
                ],
            },
        ],
        max_tokens=300,
        temperature=0,
    )

    raw = response.choices[0].message.content or ""
    logger.info("GPT-4o raw response: %s", raw)
    return raw
