from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://user:password@postgres-catalog:5432/catalog_db"

    class Config:
        env_file = ".env"


settings = Settings()
