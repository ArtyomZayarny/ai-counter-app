import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql+asyncpg://localhost/ytilities")
# Railway uses postgres:// but asyncpg needs postgresql+asyncpg://
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+asyncpg://", 1)
elif DATABASE_URL.startswith("postgresql://") and "+asyncpg" not in DATABASE_URL:
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)
# asyncpg doesn't support sslmode param — replace with ssl=require
DATABASE_URL = DATABASE_URL.replace("sslmode=require", "ssl=require")

JWT_SECRET = os.environ["JWT_SECRET"]
JWT_ALGORITHM = os.environ.get("JWT_ALGORITHM", "HS256")
JWT_EXPIRY_MINUTES = int(os.environ.get("JWT_EXPIRY_MINUTES", "10080"))  # 7 days

GOOGLE_CLIENT_ID = os.environ["GOOGLE_CLIENT_ID"]

APPLE_BUNDLE_ID = os.environ.get("APPLE_BUNDLE_ID", "")

OPENAI_API_KEY = os.environ["OPENAI_API_KEY"]
