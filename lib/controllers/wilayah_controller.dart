import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:turf/turf.dart' as turf;
import '../models/wilayah_model.dart';
import '../helper/clickable_polygon.dart';

List<WilayahModel> _parseJsonIsolate(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    throw Exception("File not found at $filePath");
  }
  final jsonString = file.readAsStringSync();
  return wilayahModelFromJson(jsonString);
}

class GeoJsonResult {
  final List<ClickablePolygon> polygons;
  final LatLng globalCenter;

  GeoJsonResult({required this.polygons, required this.globalCenter});
}

class WilayahController {
  List<WilayahModel> data = [];
  List<WilayahModel> wilayahList = [];
  List<ClickablePolygon> areaPolygons = [];
  List<Marker> areaMarker = [];

  int _countWilayahNormal = 0;
  int get countWilayahNormal => _countWilayahNormal;

  int _countWilayahAgakNormal = 0;
  int get countWilayahAgakNormal => _countWilayahAgakNormal;

  int _countWilayahAtensi = 0;
  int get countWilayahAtensi => _countWilayahAtensi;

  WilayahController(){
  }

  Future<void> loadWilayahData() async {
    if (!Platform.isWindows) {
      throw UnsupportedError("This path resolution is specific to Windows.");
    }
  
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null) {
      throw Exception("Could not find USERPROFILE environment variable.");
    }
  
    final String targetPath = '$userProfile\\AppData\\Roaming\\SatgasPRR\\monitor_bencana_d\\json_data\\get_wilayah_all.json';

    try {
      List<WilayahModel> result = await Isolate.run(() => _parseJsonIsolate(targetPath));
      data = result;
    } catch (e) {
      debugPrint("Error reading/parsing JSON: $e");
      rethrow;
    }
  }

  LatLng getSelectedCoordinate(String areaCode) {
    //return LatLng(0.0, 0.0);
    WilayahModel selectedAreaData = data.where((w) => w.kode == areaCode).first;
    return LatLng(selectedAreaData.latitude ?? 0.0, selectedAreaData.longitude ?? 0.0);
  }

  /*Data provinsi*/
  Future<void> selectProvinsi() async {
    List<ClickablePolygon> polygonsData = [];
    List<Marker> markerWilayah = [];
    final kodeProvinsi = {'11', '12', '13'};
    List<WilayahModel> filteredWilayah = data.where((w) => kodeProvinsi.contains(w.kode)).toList();
    wilayahList = filteredWilayah;
    _countWilayahNormal = 0;
    _countWilayahAtensi = 0;
    _countWilayahAgakNormal = 0;

    for (var w in filteredWilayah) {
      final List<ClickablePolygon> geoData = await _parseGeoJson(w.polygon, 'Provinsi', w.kode);
      if (geoData.isNotEmpty) {
        polygonsData.addAll(geoData);

        LatLng centerPoint = (w.kode == '11' ? 
          LatLng(4.15, 96.75) :
          (
            w.kode == '12' ? LatLng(2.20, 99.10) :
            LatLng(-0.70, 100.65)
          )
        );
        markerWilayah.add(
          Marker(
            point: centerPoint,
            width: 120,
            height: 40,
            child: IgnorePointer(
              child: Text(
                w.nama.replaceAll('\n', ' '),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
                ),
              ),
            ),
          ),
        );
      }
      switch (w.kondisi) {
        case 'Normal':
          _countWilayahNormal += 1;
        break;
        case 'Atensi':
          _countWilayahAtensi += 1;
        break;
        case 'Mendekati':
          _countWilayahAgakNormal += 1;
        break;
        default:
          _countWilayahNormal += 1;
      }
    }
    areaPolygons = polygonsData;
    areaMarker = markerWilayah;
  }
  /*Data provinsi*/

  /*Data provinsi*/
  Future<void> selectKabupaten(String parentCode) async {
    List<ClickablePolygon> polygonsData = [];
    List<Marker> markerWilayah = [];
    List<WilayahModel> filteredWilayah = data.where((w) => w.parentKode == parentCode).toList();
    wilayahList = filteredWilayah;
    _countWilayahNormal = 0;
    _countWilayahAtensi = 0;
    _countWilayahAgakNormal = 0;

    for (var w in filteredWilayah) {
      final List<ClickablePolygon> geoData = await _parseGeoJson(w.polygon, w.kondisi.toString(), w.kode);
      if (geoData.isNotEmpty) {
        polygonsData.addAll(geoData);

        LatLng centerPoint = geoData.first.center;
        markerWilayah.add(
          Marker(
            point: centerPoint,
            width: 120,
            height: 40,
            child: IgnorePointer(
              child: Text(
                w.nama.replaceAll('\n', ' '),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
                ),
              ),
            ),
          ),
        );
      }
      switch (w.kondisi) {
        case 'Normal':
          _countWilayahNormal += 1;
        break;
        case 'Atensi':
          _countWilayahAtensi += 1;
        break;
        case 'Mendekati':
          _countWilayahAgakNormal += 1;
        break;
        default:
          _countWilayahNormal += 1;
      }
    }
    areaPolygons = polygonsData;
    areaMarker = markerWilayah;
  }
  /*Data provinsi*/

  //Future<List<ClickablePolygon>> _parseGeoJson(
  //  String path, String kondisi, String areaCode) async {
  //  List<ClickablePolygon> results = [];
  //  //String content = await rootBundle.loadString('assets/'+path);
  //  String content;
  //  try {
  //    content = await rootBundle.loadString('assets/' + path);
  //  } catch (e) {
  //    return results;
  //  }
  //  final data = json.decode(content);

  //  for (var feature in data['features']) {
  //    var geom = feature['geometry'];
  //    List<dynamic> coordsList =
  //        geom['type'] == 'Polygon' ? [geom['coordinates']] : geom['coordinates'];

  //    for (var polyCoords in coordsList) {
  //      List<LatLng> points = (polyCoords[0] as List)
  //          .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
  //          .toList();

  //      double sumLat = 0, sumLon = 0;
  //      for (var p in points) {
  //        sumLat += p.latitude;
  //        sumLon += p.longitude;
  //      }

  //      results.add(ClickablePolygon(
  //        polygon: Polygon(
  //            points: points,
  //            isFilled: true,
  //            color: Colors.transparent,
  //            borderColor: Colors.transparent),
  //        code: areaCode,
  //        center: LatLng(sumLat / points.length, sumLon / points.length),
  //        kondisi: kondisi,
  //      ));
  //    }
  //  }
  //  return results;
  //}

  Future<List<ClickablePolygon>> _parseGeoJson(
      String path, String kondisi, String areaCode) async {
    List<ClickablePolygon> results = [];
    String content;

    try {
      content = await rootBundle.loadString('assets/$path');
    } catch (e) {
      return results; // Return empty list on failure
    }

    // 1. Parse raw json into Turf's FeatureCollection
    final jsonMap = json.decode(content);
    final featureCollection = turf.FeatureCollection.fromJson(jsonMap);

    // 2. Instantly calculate the global center of the entire file
    final globalCenterPoint = turf.center(featureCollection);
    final globalPos = globalCenterPoint.geometry!.coordinates;
    final globalCenterLatLng = LatLng(globalPos.lat.toDouble(), globalPos.lng.toDouble());

    // 3. Process the features into your ClickablePolygons
    for (var feature in featureCollection.features) {
      final geom = feature.geometry;
      if (geom == null) continue;

      List<turf.Polygon> turfPolygons = [];
      if (geom is turf.Polygon) {
        turfPolygons.add(geom);
      } else if (geom is turf.MultiPolygon) {
        for (var coords in geom.coordinates) {
          turfPolygons.add(turf.Polygon(coordinates: coords));
        }
      }

      for (var poly in turfPolygons) {
        // Index [0] is always the exterior ring of the polygon
        List<LatLng> mapPoints = poly.coordinates[0].map((pos) {
          return LatLng(pos.lat.toDouble(), pos.lng.toDouble());
        }).toList();

        // We place the global center value directly inside each polygon's center property
        results.add(ClickablePolygon(
          polygon: Polygon(
            points: mapPoints,
            isFilled: true,
            color: Colors.transparent,
            borderColor: Colors.transparent,
          ),
          code: areaCode,
          center: globalCenterLatLng, // <-- Stamped with the entire file's center!
          kondisi: kondisi,
        ));
      }
    }

    return results; // Zero changes to your existing method signature
  }
}