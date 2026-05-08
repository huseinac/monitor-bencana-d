import 'package:flutter/material.dart';
//import 'home_view.dart';
import 'styles/app_styles.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_geojson/flutter_map_geojson.dart';

import 'dart:convert';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color brandBlue = Color(0xFF22467a);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(
          seedColor: brandBlue,
          primary: brandBlue,
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: brandBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const MyHomePage(title: 'zxczxc',),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  //Future<List<Polygon>> _loadInitialProvinces() async {
  //  try {
  //    // 1. Setup the parser with high-visibility colors
  //    GeoJsonParser geoJsonParser = GeoJsonParser(
  //      defaultPolygonFillColor: Colors.blue.withOpacity(0.3), 
  //      defaultPolygonBorderColor: Colors.blue,               
  //      defaultPolygonBorderStroke: 2.0,                      
  //    );

  //    // 2. Hardcode the three province paths
  //    final List<String> provincePaths = [
  //      'assets/mapdata/11.geojson',
  //      //'assets/mapdata/12.geojson',
  //      //'assets/mapdata/13.geojson',
  //    ];

  //    debugPrint("--- STARTING PROVINCE LOAD ---");

  //    for (String path in provincePaths) {
  //      try {
  //        // Load raw string like we did in the test
  //        String geoJsonString = await rootBundle.loadString(path);
          
  //        // Parse it
  //        geoJsonParser.parseGeoJsonAsString(geoJsonString);
  //        debugPrint("Successfully parsed: $path");
  //      } catch (fileError) {
  //        debugPrint("Error loading $path: $fileError");
  //      }
  //    }

  //    debugPrint("Total Polygons ready: ${geoJsonParser.polygons.length}");
  //    return geoJsonParser.polygons;
  //  } catch (e) {
  //    debugPrint("General Load Error: $e");
  //    return [];
  //  }
  //}

  Future<List<Polygon>> _loadInitialProvinces() async {
    List<Polygon> allPolygons = [];
    
    final List<String> provincePaths = [
      'assets/mapdata/11.geojson',
      'assets/mapdata/12.geojson',
      'assets/mapdata/13.geojson',
    ];

    for (String path in provincePaths) {
      try {
        String geoJsonString = await rootBundle.loadString(path);
        final Map<String, dynamic> data = json.decode(geoJsonString);

        for (var feature in data['features']) {
          var geometry = feature['geometry'];
          var type = geometry['type'];
          var coordinates = geometry['coordinates'];

          if (type == 'Polygon') {
            allPolygons.add(_createPolygon(coordinates));
          } else if (type == 'MultiPolygon') {
            // A MultiPolygon is an array of Polygons
            for (var polyCoords in coordinates) {
              allPolygons.add(_createPolygon(polyCoords));
            }
          }
        }
      } catch (e) {
        debugPrint("Error loading $path: $e");
      }
    }
    return allPolygons;
  }

  // Helper function to handle the coordinate conversion
  Polygon _createPolygon(List<dynamic> rings) {
    // The first ring is the exterior boundary
    List<LatLng> points = [];
    for (var coord in rings[0]) {
      // GeoJSON is [Lon, Lat], FlutterMap is LatLng(Lat, Lon)
      points.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
    }

    return Polygon(
      points: points,
      color: Colors.blue.withOpacity(0.3),
      borderColor: Colors.blue,
      borderStrokeWidth: 2.0,
      isFilled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
            children: [
              Expanded(
                flex: 10,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 42,
                  )
                )
              ),
              Expanded(
                flex: 2,
                child: Container(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/logo2.png',
                          height: 42,
                        ),
                        const SizedBox(width: 14),
                        Image.asset(
                          'assets/images/icon-info.png',
                          height: 20,
                        ),
                      ],
                    )
                  ),
                )
              ),
            ],
          ),
      ),
      body: FutureBuilder<List<Polygon>>(
        future: _loadInitialProvinces(),
        builder: (context, snapshot) {
          return FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(1.5000, 99.0000),
              initialZoom: 7.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.monitorbencana.app',
              ),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
              ),
              if (snapshot.hasData)
                PolygonLayer(polygons: snapshot.data!),
            ],
          );
        },
      ),
    );
  }
}
