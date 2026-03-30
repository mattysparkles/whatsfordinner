class Env {
  static const visionApiKey = String.fromEnvironment('VISION_API_KEY', defaultValue: '');
  static const recipeApiKey = String.fromEnvironment('RECIPE_API_KEY', defaultValue: '');
}
