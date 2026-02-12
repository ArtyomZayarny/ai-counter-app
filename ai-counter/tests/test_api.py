import io
import struct
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.models.user import User

client = TestClient(app)

# Mock user for auth-protected endpoints
_mock_user = User(
    id=uuid.UUID("00000000-0000-0000-0000-000000000001"),
    email="test@test.com",
    name="Test User",
)
_mock_meter_id = "00000000-0000-0000-0000-000000000002"


def _auth_override():
    """Override get_current_user dependency to skip real auth."""
    return _mock_user


def _make_minimal_jpeg(width: int = 800, height: int = 600) -> bytes:
    """Create a minimal valid JPEG binary with given dimensions."""
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


# Override auth dependency for all tests in this module
from app.dependencies import get_current_user, get_db


async def _mock_get_db():
    """Mock DB session that auto-flushes and commits without real DB."""
    from app.models.meter import Meter

    mock_meter = Meter(
        id=uuid.UUID(_mock_meter_id),
        property_id=uuid.UUID("00000000-0000-0000-0000-000000000003"),
        utility_type="gas",
        name="Gas Meter",
    )

    # scalar_one_or_none() is sync, so use MagicMock for execute result
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = mock_meter

    mock_session = AsyncMock()
    mock_session.execute.return_value = mock_result
    yield mock_session


app.dependency_overrides[get_current_user] = _auth_override
app.dependency_overrides[get_db] = _mock_get_db


@patch("app.routers.readings.recognize_digits")
def test_successful_recognition(mock_recognize):
    mock_recognize.return_value = '{"pos1":0,"pos2":2,"pos3":3,"pos4":4,"pos5":0}'
    jpeg = _make_minimal_jpeg()

    response = client.post(
        "/recognize",
        files={"image": ("meter.jpg", io.BytesIO(jpeg), "image/jpeg")},
        data={"meter_id": _mock_meter_id},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["result"] == "02340"
    assert "reading_id" in data


@patch("app.routers.readings.recognize_digits")
def test_wrong_digit_count_returns_422(mock_recognize):
    mock_recognize.return_value = "0234"
    jpeg = _make_minimal_jpeg()

    response = client.post(
        "/recognize",
        files={"image": ("meter.jpg", io.BytesIO(jpeg), "image/jpeg")},
        data={"meter_id": _mock_meter_id},
    )

    assert response.status_code == 422
    assert response.json()["result"] == "0234"


@patch("app.routers.readings.recognize_digits")
def test_fallback_plain_text_response(mock_recognize):
    mock_recognize.return_value = "The reading is 02340."
    jpeg = _make_minimal_jpeg()

    response = client.post(
        "/recognize",
        files={"image": ("meter.jpg", io.BytesIO(jpeg), "image/jpeg")},
        data={"meter_id": _mock_meter_id},
    )

    assert response.status_code == 200
    assert response.json()["result"] == "02340"


def test_invalid_format_returns_400():
    response = client.post(
        "/recognize",
        files={"image": ("file.txt", io.BytesIO(b"hello"), "text/plain")},
        data={"meter_id": _mock_meter_id},
    )

    assert response.status_code == 400


def test_too_small_resolution_returns_400():
    jpeg = _make_minimal_jpeg(width=50, height=50)

    response = client.post(
        "/recognize",
        files={"image": ("small.jpg", io.BytesIO(jpeg), "image/jpeg")},
        data={"meter_id": _mock_meter_id},
    )

    assert response.status_code == 400


def test_health_returns_200():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@patch("app.routers.readings.recognize_digits")
def test_chain_of_thought_response(mock_recognize):
    """GPT-4o returns chain-of-thought text followed by JSON."""
    mock_recognize.return_value = (
        "Looking at the drums left to right:\n"
        "Drum 1: shows 0\nDrum 2: shows 1\nDrum 3: shows 8\n"
        "Drum 4: shows 1\nDrum 5: shows 4\n\n"
        '{"pos1": 0, "pos2": 1, "pos3": 8, "pos4": 1, "pos5": 4}'
    )
    jpeg = _make_minimal_jpeg()

    response = client.post(
        "/recognize",
        files={"image": ("meter.jpg", io.BytesIO(jpeg), "image/jpeg")},
        data={"meter_id": _mock_meter_id},
    )

    assert response.status_code == 200
    assert response.json()["result"] == "01814"


@patch("app.routers.readings.recognize_digits")
def test_out_of_range_values_fall_back_to_normalize(mock_recognize):
    """If pos values are out of 0-9 range, fall back to plain-text normalization."""
    mock_recognize.return_value = '{"pos1": 0, "pos2": 12, "pos3": 8, "pos4": 1, "pos5": 4}'
    jpeg = _make_minimal_jpeg()

    response = client.post(
        "/recognize",
        files={"image": ("meter.jpg", io.BytesIO(jpeg), "image/jpeg")},
        data={"meter_id": _mock_meter_id},
    )

    # Falls back to normalize_digits which extracts: 0, 1, 2, 8, 1, 4 -> "01281" (first 5)
    assert response.status_code == 200
    assert len(response.json()["result"]) == 5
