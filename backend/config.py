from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    DATABASE_URL: str = "data/dog_care.duckdb"
    OPENAI_API_KEY: str | None = None
    GEMINI_API_KEY: str | None = None
    NVIDIA_API_KEY: str | None = "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"
    NVIDIA_BASE_URL: str = "https://integrate.api.nvidia.com/v1"
    
    class Config:
        env_file = ".env"

def get_settings():
    return Settings()
