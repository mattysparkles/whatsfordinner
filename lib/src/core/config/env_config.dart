enum AppEnvironment { dev, staging, prod }

class EnvConfig {
  const EnvConfig({
    required this.environment,
    required this.useMocks,
    required this.recipeApiBaseUrl,
    required this.visionApiBaseUrl,
    this.recipeApiKey = '',
    this.visionApiKey = '',
    this.visionModel = 'gpt-4.1-mini',
    this.visionRequestTimeoutMs = 30000,
    this.visionMaxRetries = 2,
    this.visionLogEnabled = false,
    this.recipeModel = 'gpt-4.1-mini',
    this.recipeRequestTimeoutMs = 25000,
    this.recipeMaxRetries = 2,
    this.recipeCacheTtl = const Duration(minutes: 10),
  });

  final AppEnvironment environment;
  final bool useMocks;
  final String recipeApiBaseUrl;
  final String visionApiBaseUrl;
  final String recipeApiKey;
  final String visionApiKey;
  final String visionModel;
  final int visionRequestTimeoutMs;
  final int visionMaxRetries;
  final bool visionLogEnabled;
  final String recipeModel;
  final int recipeRequestTimeoutMs;
  final int recipeMaxRetries;
  final Duration recipeCacheTtl;

  static EnvConfig fromDartDefines() {
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    const useMocks = bool.fromEnvironment('USE_MOCKS', defaultValue: true);

    return EnvConfig(
      environment: AppEnvironment.values.firstWhere(
        (value) => value.name == env,
        orElse: () => AppEnvironment.dev,
      ),
      useMocks: useMocks,
      recipeApiBaseUrl: const String.fromEnvironment(
        'RECIPE_API_BASE_URL',
        defaultValue: 'https://example.com/recipes',
      ),
      visionApiBaseUrl: const String.fromEnvironment(
        'VISION_API_BASE_URL',
        defaultValue: 'https://api.openai.com/v1',
      ),
      recipeApiKey: const String.fromEnvironment('RECIPE_API_KEY'),
      visionApiKey: const String.fromEnvironment('VISION_API_KEY'),
      visionModel: const String.fromEnvironment('VISION_MODEL', defaultValue: 'gpt-4.1-mini'),
      visionRequestTimeoutMs: int.fromEnvironment('VISION_TIMEOUT_MS', defaultValue: 30000),
      visionMaxRetries: int.fromEnvironment('VISION_MAX_RETRIES', defaultValue: 2),
      visionLogEnabled: bool.fromEnvironment('VISION_LOGGING_ENABLED', defaultValue: false),
      recipeModel: const String.fromEnvironment('RECIPE_MODEL', defaultValue: 'gpt-4.1-mini'),
      recipeRequestTimeoutMs: int.fromEnvironment('RECIPE_TIMEOUT_MS', defaultValue: 25000),
      recipeMaxRetries: int.fromEnvironment('RECIPE_MAX_RETRIES', defaultValue: 2),
      recipeCacheTtl: Duration(seconds: int.fromEnvironment('RECIPE_CACHE_TTL_SECONDS', defaultValue: 600)),
    );
  }
}
