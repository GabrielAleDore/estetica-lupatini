from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import declarative_base
from app.core.config import settings

# Limpeza defensiva caso venha prefixo duplicado
db_url = settings.DATABASE_URL.strip()
if db_url.startswith("DATABASE_URL="):
    db_url = db_url.replace("DATABASE_URL=", "", 1).strip()

# Garante que a URL use o driver assíncrono asyncpg (mesmo se o usuário colar postgresql:// padrão)
if db_url.startswith("postgresql://"):
    db_url = db_url.replace("postgresql://", "postgresql+asyncpg://", 1)
elif db_url.startswith("postgres://"):
    db_url = db_url.replace("postgres://", "postgresql+asyncpg://", 1)

# Se estiver conectando via Pooler do Supabase (porta 6543), desativa cache de prepared statements
connect_args = {}
if ":6543" in db_url or "pooler.supabase.com" in db_url:
    connect_args = {
        "prepared_statement_cache_size": 0,
        "statement_cache_size": 0
    }

engine = create_async_engine(
    db_url,
    echo=False,
    pool_pre_ping=True,
    pool_recycle=30,      # Recicla conexões antes do timeout de inatividade do PgBouncer (60s)
    pool_timeout=10,      # Timeout para obtenção de conexão no pool
    pool_size=10,
    max_overflow=20,
    connect_args=connect_args
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
    class_=AsyncSession
)

Base = declarative_base()


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Dependency do FastAPI para fornecer uma sessão de banco assíncrona.
    Garante encerramento e rollback em caso de falhas.
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
