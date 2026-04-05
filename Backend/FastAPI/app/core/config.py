from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    MONGO_URI: str = "mongodb://localhost:27017"
    MONGO_DB_NAME: str = "lattice-test"

    FIREBASE_CREDENTIALS_PATH: str = "firebase-service-account.json"
    FIREBASE_CREDENTIALS_JSON: str = ""  # Full JSON string (for cloud deploys without a file)
    FIREBASE_API_KEY: str = ""  # Firebase Web API key (for email/password sign-in)

    OPENAI_API_KEY: str = ""  # OpenAI API key (used by litellm for the ADK agent)
    GOOGLE_API_KEY: str = ""  # Google API key (YouTube Data v3, Books, Custom Search)
    GOOGLE_CSE_ID: str = ""  # Google Custom Search Engine ID (for articles)
    EVENTBRITE_TOKEN: str = ""  # Eventbrite private OAuth token (for event details)

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
