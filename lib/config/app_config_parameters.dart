class AppConfigParameters {
  // Build mode configurations
  static const bool isRelease = bool.fromEnvironment('dart.vm.product');
  
  // Polygon tracking configurations
  static const int minPolygonPoints = isRelease ? 25 : 5;
  static const double minPolygonCloseDistance = 5.0; // in meters
  
  // Layout configurations
  static const double mapHeightRatio = 0.65;
  static const double buttonHeightRatio = 0.1;
  static const double headerHeight = 80.0;
  static const double titleHeight = 60.0;
} 