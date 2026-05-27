import 'package:maps_toolkit/maps_toolkit.dart';

class GeofenceHelper {
  // Users can mark attendance from anywhere within this distance of an
  // allocated panchayat's saved polygon (inside the polygon, or up to 2km
  // beyond its edges).
  static const double checkInRadiusMeters = 2000.0;

  /// Parse a string like "18.8194177,82.6839473" into LatLng
  static LatLng? parseLatLng(String pointStr) {
    try {
      final parts = pointStr.split(',');
      if (parts.length == 2) {
        final lat = double.parse(parts[0].trim());
        final lng = double.parse(parts[1].trim());
        return LatLng(lat, lng);
      }
    } catch (e) {
      // ignore parsing errors for single points
    }
    return null;
  }

  /// Convert list of string points to `List<LatLng>`
  static List<LatLng> getPolygonPoints(List<dynamic> stringPoints) {
    List<LatLng> polygon = [];
    for (var pointStr in stringPoints) {
      if (pointStr is String) {
        final latLng = parseLatLng(pointStr);
        if (latLng != null) {
          polygon.add(latLng);
        }
      }
    }
    return polygon;
  }

  /// Check if a user's location is inside, or within [checkInRadiusMeters] of, a given polygon.
  static bool isWithinGeofence(LatLng userLocation, List<LatLng> polygon) {
    if (polygon.isEmpty) return false;
    if (polygon.length == 1) {
      // If only one point, check distance
      final distance =
          SphericalUtil.computeDistanceBetween(userLocation, polygon.first);
      return distance <= checkInRadiusMeters;
    }

    // Check if exactly inside the polygon
    if (PolygonUtil.containsLocation(userLocation, polygon, true)) {
      return true;
    }

    // Check if within 50m of the boundary edge
    if (PolygonUtil.isLocationOnEdge(userLocation, polygon, true,
        tolerance: checkInRadiusMeters)) {
      return true;
    }

    return false;
  }
}
