abstract final class AppConfig {
  static const appVersion = '1.0.0';

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://staging-back.interactivecore.app/api/v1',
  );
}
