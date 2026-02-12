import base64
import logging
import os

from openai import OpenAI

logger = logging.getLogger(__name__)

OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")

GAS_SYSTEM_PROMPT = (
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

GAS_USER_PROMPT = (
    "Look at the mechanical rotating drum wheels in the center of this gas meter. "
    "Ignore all printed text, serial numbers, and specs. "
    "Read only the 5 black/white drums left to right.\n\n"
    "Step 1: Describe what you see on each drum position.\n"
    "Step 2: Return the JSON with your reading."
)

ELECTRICITY_SYSTEM_PROMPT = (
    "You are a precision electricity meter digit reader.\n\n"
    "WHAT TO LOOK FOR:\n"
    "Find the LCD or LED digital display showing the main kWh reading. "
    "This is typically the largest number on the display, shown using 7-segment digits. "
    "The display may have a kWh label nearby.\n\n"
    "IGNORE EVERYTHING ELSE on the meter:\n"
    "- Serial numbers, meter ID numbers\n"
    "- Tariff indicators (T1, T2, etc.)\n"
    "- Date, time, or mode displays\n"
    "- Voltage, current, or power readings\n"
    "- Any decimal portion after a dot or comma\n"
    "- Barcodes, QR codes, brand names\n"
    "- Only read the MAIN kWh INTEGER DIGITS.\n\n"
    "READING RULES:\n"
    "1. Read exactly 6 integer digits of the main kWh reading, LEFT to RIGHT.\n"
    "2. IGNORE any digits after a decimal point, dot, or comma.\n"
    "3. Leading zeros matter: 001234 stays 001234.\n"
    "4. If a digit is partially visible or flickering, read the most likely value.\n"
    "5. Verify each digit independently before answering.\n\n"
    "RESPONSE FORMAT:\n"
    "Step 1: Describe what you see on each digit position (left to right).\n"
    "Step 2: Return JSON: {\"pos1\": D, \"pos2\": D, \"pos3\": D, \"pos4\": D, \"pos5\": D, \"pos6\": D} "
    "where D is a single integer 0-9."
)

ELECTRICITY_USER_PROMPT = (
    "Look at the LCD/LED display on this electricity meter. "
    "Ignore serial numbers, tariff indicators, dates, and decimal portions. "
    "Read only the 6 main integer kWh digits left to right.\n\n"
    "Step 1: Describe what you see on each digit position.\n"
    "Step 2: Return the JSON with your reading."
)

WATER_SYSTEM_PROMPT = (
    "You are a precision water meter digit reader.\n\n"
    "WHAT TO LOOK FOR:\n"
    "Find the horizontal row of MECHANICAL ROTATING DRUM WHEELS (rollers) on the meter. "
    "These drums are inside a rectangular window and each drum shows a single digit (0-9) through the window slot. "
    "The water meter typically has a round face, may have a blue ring, and shows m\u00B3 (cubic meters) as the unit. "
    "There may be a small rotary dial at the bottom — IGNORE it.\n\n"
    "IGNORE EVERYTHING ELSE on the meter:\n"
    "- Serial numbers printed flat on the label\n"
    "- Year of manufacture, QR codes, barcodes\n"
    "- Technical specs, brand names, model numbers\n"
    "- Small rotary dials or flow indicators\n"
    "- Only read the MECHANICAL ROTATING DRUMS.\n\n"
    "COLOR RULES:\n"
    "- BLACK or WHITE background drums = INTEGER reading (left side). READ THESE.\n"
    "- RED background drums = decimal fraction (right side). COMPLETELY IGNORE red drums.\n\n"
    "READING RULES:\n"
    "1. Read exactly 5 black/white drums, strictly LEFT to RIGHT.\n"
    "2. Read the digit most centered in the viewing window for each drum.\n"
    "3. If a drum is between two digits (transitioning), report the LOWER digit.\n"
    "4. Leading zeros matter: 00042 stays 00042.\n"
    "5. Verify each drum independently before answering.\n\n"
    "RESPONSE FORMAT:\n"
    "Step 1: Describe what you see on each drum (left to right).\n"
    "Step 2: Return JSON: {\"pos1\": D, \"pos2\": D, \"pos3\": D, \"pos4\": D, \"pos5\": D} "
    "where D is a single integer 0-9."
)

WATER_USER_PROMPT = (
    "Look at the mechanical rotating drum wheels on this water meter. "
    "Ignore all printed text, serial numbers, specs, and any small rotary dials. "
    "Read only the 5 black/white drums left to right.\n\n"
    "Step 1: Describe what you see on each drum position.\n"
    "Step 2: Return the JSON with your reading."
)

_PROMPTS = {
    "gas": (GAS_SYSTEM_PROMPT, GAS_USER_PROMPT),
    "electricity": (ELECTRICITY_SYSTEM_PROMPT, ELECTRICITY_USER_PROMPT),
    "water": (WATER_SYSTEM_PROMPT, WATER_USER_PROMPT),
}


def _detect_media_type(data: bytes) -> str:
    if data[:2] == b'\xff\xd8':
        return "image/jpeg"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    return "image/jpeg"


def recognize_digits(image_data: bytes, content_type: str, utility_type: str = "gas") -> str:
    """Send image to GPT-4o Vision API and return raw response text."""
    b64 = base64.b64encode(image_data).decode("utf-8")
    media_type = _detect_media_type(image_data)

    system_prompt, user_prompt = _PROMPTS.get(utility_type, _PROMPTS["gas"])

    logger.info("Sending image to GPT-4o: %d bytes, type=%s, utility=%s", len(image_data), media_type, utility_type)

    client = OpenAI(api_key=OPENAI_API_KEY)

    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": user_prompt},
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
