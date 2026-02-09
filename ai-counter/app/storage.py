import os
import uuid
from pathlib import Path

RESULTS_DIR = Path("photos/results")


def save_image(image_data: bytes) -> str:
    """Save original image to photos/results/<uuid>.jpg. Return the UUID."""
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    image_id = str(uuid.uuid4())
    file_path = RESULTS_DIR / f"{image_id}.jpg"
    file_path.write_bytes(image_data)
    return image_id
