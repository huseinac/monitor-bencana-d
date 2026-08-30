//import 'package:flutter_map/flutter_map.dart';
//import 'package:latlong2/latlong.dart';
//class ClickablePolygon {
//  final Polygon polygon;
//  final String code;
//  final LatLng center;
//  final String kondisi;

//  ClickablePolygon({
//    required this.polygon,
//    required this.code,
//    required this.center,
//    required this.kondisi,
//  });
//}
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ClickablePolygon {
  final Polygon polygon;
  final String code;
  final LatLng center;
  final String kondisi;
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  ClickablePolygon({
    required this.polygon,
    required this.code,
    required this.center,
    required this.kondisi,
  })  : minLat = polygon.points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
        maxLat = polygon.points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
        minLng = polygon.points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
        maxLng = polygon.points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

  /// Fast Bounding-Box + Ray-Casting Point Check
  bool contains(LatLng point) {
    // 1. Instant Bounding Box Rejection
    if (point.latitude < minLat ||
        point.latitude > maxLat ||
        point.longitude < minLng ||
        point.longitude > maxLng) {
      return false;
    }

    // 2. Exact Ray-Casting (only executed if inside bounding box)
    int i, j = polygon.points.length - 1;
    bool oddNodes = false;
    final double x = point.longitude;
    final double y = point.latitude;
    
    for (i = 0; i < polygon.points.length; i++) {
      if ((polygon.points[i].latitude < y && polygon.points[j].latitude >= y ||
              polygon.points[j].latitude < y && polygon.points[i].latitude >= y) &&
          (polygon.points[i].longitude <= x || polygon.points[j].longitude <= x)) {
        if (polygon.points[i].longitude +
                (y - polygon.points[i].latitude) /
                    (polygon.points[j].latitude - polygon.points[i].latitude) *
                    (polygon.points[j].longitude - polygon.points[i].longitude) <
            x) {
          oddNodes = !oddNodes;
        }
      }
      j = i;
    }
    return oddNodes;
  }
}