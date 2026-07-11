import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
class ClickablePolygon {
  final Polygon polygon;
  final String code;
  final LatLng center;
  final String kondisi;

  ClickablePolygon({
    required this.polygon,
    required this.code,
    required this.center,
    required this.kondisi,
  });
}