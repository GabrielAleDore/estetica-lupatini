from typing import List
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "Estética Lupatini API"
    API_V1_STR: str = "/api/v1"
    
    # Supabase Settings
    SUPABASE_URL: str = "https://your-project.supabase.co"
    SUPABASE_KEY: str = "your-anon-or-service-role-key"
    SUPABASE_JWT_SECRET: str = "your-supabase-jwt-secret"
    SUPABASE_JWT_ALGORITHM: str = "HS256"
    
    # Database Settings (Direct connection to Supabase PostgreSQL or Pooler)
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:54322/postgres"
    
    # Ambiente de Execução
    ENVIRONMENT: str = "development"  # 'development', 'staging', 'production'
    
    # CORS
    BACKEND_CORS_ORIGINS: List[str] = ["*"]
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore"
    )


settings = Settings()
