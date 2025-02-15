class AppConfig {
  static const String _buildEnv = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
  
  static bool get isProduction => _buildEnv == 'production';
  static bool get isDevelopment => _buildEnv == 'development';

  // Add your environment specific values here
  static String get googleMapsApiKey => isProduction 
    ? 'AIzaSyAyye03zRtYOKOHFdtOvo99MnyHxzm6wBg'
    : 'AIzaSyBGfU3qCOTfqg52zENVopgHNTL0riF_zrg';
} 