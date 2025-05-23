class AppConfigParameters {
  // Build mode configurations
  static const bool isRelease = bool.fromEnvironment('dart.vm.product');
  
  // Polygon tracking configurations
  static const int minPolygonPoints = isRelease ? 25 : 5;
  static const double minPolygonCloseDistance = 50.0; // in meters
  
  // Layout configurations
  static const double buttonHeightRatio = 0.11;
} 