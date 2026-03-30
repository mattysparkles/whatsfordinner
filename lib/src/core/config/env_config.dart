enum AppEnvironment { dev, staging, prod }

class EnvConfig {
  const EnvConfig({
    required this.environment,
    required this.useMocks,
    required this.recipeApiBaseUrl,
    required this.visionApiBaseUrl,
    this.recipeApiKey = '',
    this.visionApiKey = '',
  });

  final AppEnvironment environment;
  final bool useMocks;
  final String recipeApiBaseUrl;
  final String visionApiBaseUrl;
  final String recipeApiKey;
  final String visionApiKey;

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
        defaultValue: 'https://example.com/vision',
      ),
      recipeApiKey: const String.fromEnvironment('RECIPE_API_KEY'),
      visionApiKey: const String.fromEnvironment('VISION_API_KEY'),
    );
  }
}
