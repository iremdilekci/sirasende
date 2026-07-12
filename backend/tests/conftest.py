from collections.abc import AsyncGenerator

import pytest

from app.core.database import engine


@pytest.fixture(autouse=True)
async def clear_engine_connections() -> AsyncGenerator[None, None]:
    yield
    await engine.dispose()
