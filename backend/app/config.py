from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file='.env', env_prefix='PANTRY_GATEWAY_', extra='ignore')

    openai_api_key: str = ''
    openai_model_vision: str = 'gpt-4.1-mini'
    openai_model_recipe: str = 'gpt-4.1-mini'
    openai_base_url: str = 'https://api.openai.com/v1'

    instacart_partner_id: str = ''
    instacart_api_key: str = ''
    instacart_api_base_url: str = 'https://connect.instacart.com'
    instacart_hosted_link_ttl_seconds: int = 86400

    request_timeout_seconds: float = 30.0
    rate_limit_per_minute: int = 60


settings = Settings()
