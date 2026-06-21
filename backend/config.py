from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    pierre_api_key: str
    anthropic_api_key: str
    discord_webhook_url: str = ""
    database_url: str = "sqlite:///./gestor.db"

    class Config:
        env_file = ".env"


settings = Settings()
