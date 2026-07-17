import os
os.environ["JWT_SECRET_KEY"] = "test-secret-key-1234567890-test-secret-key-1234567890"
os.environ["JWT_ALGORITHM"] = "HS256"
os.environ["JWT_ACCESS_TOKEN_EXPIRE_MINUTES"] = "30"

from collections.abc import AsyncGenerator

import pytest

from app.core.database import engine


@pytest.fixture(autouse=True)
async def clear_engine_connections() -> AsyncGenerator[None, None]:
    yield
    await engine.dispose()
