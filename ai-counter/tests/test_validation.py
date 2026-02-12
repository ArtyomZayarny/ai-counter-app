import struct

import pytest

from app.validation import (
    ValidationError,
    _get_jpeg_dimensions,
    _get_png_dimensions,
    get_image_dimensions,
)


def _make_minimal_jpeg(width: int = 800, height: int = 600) -> bytes:
    sof = b"\xFF\xD8"
    sof += b"\xFF\xC0"
    sof += struct.pack(">H", 11)
    sof += b"\x08"
    sof += struct.pack(">H", height)
    sof += struct.pack(">H", width)
    sof += b"\x01\x01\x11\x00"
    sof += b"\xFF\xD9"
    return sof


def _make_minimal_png(width: int = 800, height: int = 600) -> bytes:
    signature = b"\x89PNG\r\n\x1a\n"
    ihdr_data = struct.pack(">II", width, height) + b"\x08\x02\x00\x00\x00"
    ihdr_length = struct.pack(">I", len(ihdr_data))
    ihdr_type = b"IHDR"
    ihdr_crc = struct.pack(">I", 0)  # CRC not validated by our parser
    return signature + ihdr_length + ihdr_type + ihdr_data + ihdr_crc


class TestGetJpegDimensions:
    def test_valid_jpeg_returns_correct_dimensions(self):
        data = _make_minimal_jpeg(1024, 768)
        width, height = _get_jpeg_dimensions(data)
        assert width == 1024
        assert height == 768

    def test_corrupt_jpeg_raises_validation_error(self):
        data = b"\xFF\xD8\x00\x00"  # SOI then invalid marker
        with pytest.raises(ValidationError, match="Invalid JPEG"):
            _get_jpeg_dimensions(data)


class TestGetPngDimensions:
    def test_valid_png_returns_correct_dimensions(self):
        data = _make_minimal_png(1920, 1080)
        width, height = _get_png_dimensions(data)
        assert width == 1920
        assert height == 1080

    def test_corrupt_png_raises_validation_error(self):
        data = b"\x00\x00\x00\x00" + b"\x00" * 20
        with pytest.raises(ValidationError, match="Invalid PNG"):
            _get_png_dimensions(data)


class TestGetImageDimensions:
    def test_unsupported_content_type_raises_validation_error(self):
        with pytest.raises(ValidationError, match="Unsupported image format"):
            get_image_dimensions(b"", "image/gif")
