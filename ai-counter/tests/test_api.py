import io
import struct
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _make_minimal_jpeg(width: int = 800, height: int = 600) -> bytes:
    """Create a minimal valid JPEG binary with given dimensions."""
    # SOI + SOF0 marker with dimensions
    sof = b"\xFF\xD8"  # SOI
    sof += b"\xFF\xC0"  # SOF0
    sof += struct.pack(">H", 11)  # length
    sof += b"\x08"  # precision
    sof += struct.pack(">H", height)
    sof += struct.pack(">H", width)
    sof += b"\x01"  # num components
    sof += b"\x01\x11\x00"  # component
    sof += b"\xFF\xD9"  # EOI
    return sof


@patch("app.main.recognize_digits")
def test_successful_recognition(mock_recognize):
    mock_recognize.return_value = '{"pos1":0,"pos2":2,"pos3":3,"pos4":4,"pos5":0}'
    jpeg = _make_minimal_jpeg()

    response = client.post(
        "/recognize",
        files={"image": ("meter.jpg", io.BytesIO(jpeg), "image/jpeg")},
    )

    assert response.status_code == 200
    assert response.json() == {"result": "02340"}


@patch("app.main.recognize_digits")
def test_wrong_digit_count_returns_422(mock_recognize):
    mock_recognize.return_value = "0234"
    jpeg = _make_minimal_jpeg()

    response = client.post(
        "/recognize",
        files={"image": ("meter.jpg", io.BytesIO(jpeg), "image/jpeg")},
    )

    assert response.status_code == 422
    assert response.json()["result"] == "0234"


@patch("app.main.recognize_digits")
def test_fallback_plain_text_response(mock_recognize):
    mock_recognize.return_value = "The reading is 02340."
    jpeg = _make_minimal_jpeg()

    response = client.post(
        "/recognize",
        files={"image": ("meter.jpg", io.BytesIO(jpeg), "image/jpeg")},
    )

    assert response.status_code == 200
    assert response.json()["result"] == "02340"


def test_invalid_format_returns_400():
    response = client.post(
        "/recognize",
        files={"image": ("file.txt", io.BytesIO(b"hello"), "text/plain")},
    )

    assert response.status_code == 400


def test_too_small_resolution_returns_400():
    jpeg = _make_minimal_jpeg(width=640, height=480)

    response = client.post(
        "/recognize",
        files={"image": ("small.jpg", io.BytesIO(jpeg), "image/jpeg")},
    )

    assert response.status_code == 400
