import struct
import zlib
from fastapi import UploadFile


ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/heic", "image/heif", "application/octet-stream"}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB
MIN_WIDTH = 100
MIN_HEIGHT = 100


class ValidationError(Exception):
    def __init__(self, detail: str):
        self.detail = detail


def _get_jpeg_dimensions(data: bytes) -> tuple[int, int]:
    """Extract width and height from JPEG binary data."""
    offset = 2
    while offset < len(data):
        if data[offset] != 0xFF:
            raise ValidationError("Invalid JPEG structure")
        marker = data[offset + 1]
        if marker in (0xC0, 0xC1, 0xC2):
            height = struct.unpack(">H", data[offset + 5 : offset + 7])[0]
            width = struct.unpack(">H", data[offset + 7 : offset + 9])[0]
            return width, height
        length = struct.unpack(">H", data[offset + 2 : offset + 4])[0]
        offset += 2 + length
    raise ValidationError("Could not determine JPEG dimensions")


def _get_png_dimensions(data: bytes) -> tuple[int, int]:
    """Extract width and height from PNG binary data."""
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValidationError("Invalid PNG structure")
    width = struct.unpack(">I", data[16:20])[0]
    height = struct.unpack(">I", data[20:24])[0]
    return width, height


def _detect_format(data: bytes) -> str:
    """Detect image format from magic bytes."""
    if data[:2] == b'\xff\xd8':
        return "jpeg"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "png"
    return "unknown"


def get_image_dimensions(data: bytes, content_type: str) -> tuple[int, int]:
    """Return (width, height) for JPEG or PNG image data."""
    fmt = _detect_format(data)
    if fmt == "jpeg":
        return _get_jpeg_dimensions(data)
    if fmt == "png":
        return _get_png_dimensions(data)
    raise ValidationError(f"Unsupported image format")


async def validate_image(file: UploadFile) -> bytes:
    """Validate uploaded image and return its bytes.

    Raises ValidationError for invalid input.
    """
    data = await file.read()

    if len(data) > MAX_FILE_SIZE:
        raise ValidationError(
            f"File size {len(data)} bytes exceeds maximum {MAX_FILE_SIZE} bytes"
        )

    try:
        width, height = get_image_dimensions(data, "")
    except (struct.error, IndexError, zlib.error) as e:
        raise ValidationError(f"Could not read image dimensions: {e}")

    if width < MIN_WIDTH or height < MIN_HEIGHT:
        raise ValidationError(
            f"Image resolution {width}x{height} is below minimum {MIN_WIDTH}x{MIN_HEIGHT}"
        )

    return data


def normalize_digits(raw: str) -> str:
    """Strip all non-digit characters from the string. ASCII digits only."""
    return "".join(c for c in raw if c in "0123456789")


def validate_digit_count(digits: str) -> bool:
    """Return True if exactly 5 digits."""
    return len(digits) == 5
