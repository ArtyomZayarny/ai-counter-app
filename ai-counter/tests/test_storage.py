import uuid

from app.storage import save_image


class TestSaveImage:
    def test_file_exists_with_correct_content(self, tmp_path, monkeypatch):
        monkeypatch.setattr("app.storage.RESULTS_DIR", tmp_path)
        data = b"\xFF\xD8fake-jpeg-data"

        image_id = save_image(data)

        saved = tmp_path / f"{image_id}.jpg"
        assert saved.exists()
        assert saved.read_bytes() == data

    def test_returns_valid_uuid(self, tmp_path, monkeypatch):
        monkeypatch.setattr("app.storage.RESULTS_DIR", tmp_path)

        image_id = save_image(b"data")

        parsed = uuid.UUID(image_id)
        assert str(parsed) == image_id
