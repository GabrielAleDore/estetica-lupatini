from typing import AsyncGenerator, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import Depends

from app.core.database import get_db
from app.core.security import get_current_user

# Re-exporting dependencies for clean DI across routers
__all__ = ["get_db", "get_current_user", "AsyncSession"]
