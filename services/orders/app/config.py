from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://user:password@postgres-orders:5432/orders_db"

    class Config:
        env_file = ".env"


settings = Settings()
