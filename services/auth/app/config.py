from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://user:password@postgres-auth:5432/auth_db"
    redis_url: str = "redis://redis:6379/0"
    jwt_secret: str = "change-me-in-production-super-secret-key"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    cookie_secure: bool = True

    class Config:
        env_file = ".env"


settings = Settings()
