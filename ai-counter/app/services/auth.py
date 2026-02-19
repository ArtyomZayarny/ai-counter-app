import time
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from app.config import JWT_ALGORITHM, JWT_EXPIRY_MINUTES, JWT_SECRET

# Cache Apple's JWKS for 1 hour
_apple_jwks_cache: dict | None = None
_apple_jwks_fetched_at: float = 0


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode(), hashed.encode())


def create_access_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=JWT_EXPIRY_MINUTES)
    payload = {"sub": user_id, "exp": expire}
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str) -> str | None:
    """Decode JWT and return user_id, or None if invalid/expired."""
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload.get("sub")
    except jwt.PyJWTError:
        return None


async def _get_apple_jwks() -> dict:
    """Fetch Apple's JWKS, cached for 1 hour."""
    import httpx

    global _apple_jwks_cache, _apple_jwks_fetched_at
    if _apple_jwks_cache and (time.time() - _apple_jwks_fetched_at) < 3600:
        return _apple_jwks_cache

    async with httpx.AsyncClient() as client:
        resp = await client.get("https://appleid.apple.com/auth/keys")
        resp.raise_for_status()
        _apple_jwks_cache = resp.json()
        _apple_jwks_fetched_at = time.time()
        return _apple_jwks_cache


async def verify_apple_token(identity_token: str, bundle_id: str) -> dict | None:
    """Verify an Apple identity token and return the decoded payload, or None."""
    from jwt.algorithms import RSAAlgorithm

    try:
        # Decode JWT header to get kid
        header = jwt.get_unverified_header(identity_token)
        kid = header.get("kid")
        if not kid:
            return None

        # Fetch Apple's public keys
        jwks = await _get_apple_jwks()
        matching_key = None
        for key in jwks.get("keys", []):
            if key.get("kid") == kid:
                matching_key = key
                break

        if not matching_key:
            return None

        # Convert JWK to public key
        public_key = RSAAlgorithm.from_jwk(matching_key)

        # Verify and decode the token
        payload = jwt.decode(
            identity_token,
            public_key,
            algorithms=["RS256"],
            audience=bundle_id,
            issuer="https://appleid.apple.com",
        )
        return payload
    except (jwt.PyJWTError, KeyError, ValueError, Exception):
        return None
