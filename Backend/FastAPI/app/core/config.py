from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    MONGO_URI: str = "mongodb://localhost:27017"
    MONGO_DB_NAME: str = "lattice-test"

    FIREBASE_CREDENTIALS_PATH: str = "firebase-service-account.json"
    FIREBASE_API_KEY: str = ""  # Firebase Web API key (for email/password sign-in)

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
