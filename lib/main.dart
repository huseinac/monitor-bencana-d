import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'mapdata/map_data.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  static const Color brandBlue = Color(0xFF22467a);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitor Bencana',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: brandBlue, primary: brandBlue),
        appBarTheme: const AppBarTheme(backgroundColor: brandBlue, foregroundColor: Colors.white, elevation: 0),
      ),
      home: const MyHomePage(title: 'Monitor Bencana'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final MapController _mapController = MapController();
  late Future<List<Polygon>> _polygonFuture;
  String? _selectedProvinceId;
  bool _isHandCursor = false;
  
  List<Marker> _regencyMarkers = [];

  @override
  void initState() {
    super.initState();
    _polygonFuture = _loadInitialProvinces();
  }

  Future<List<Polygon>> _loadInitialProvinces() async {
    List<Polygon> allPolygons = [];
    final List<String> provincePaths = ['assets/mapdata/11.geojson', 'assets/mapdata/12.geojson', 'assets/mapdata/13.geojson'];

    for (String path in provincePaths) {
      final polygons = await _parseGeoJson(path, 'Provinsi');
      allPolygons.addAll(polygons);
    }
    return allPolygons;
  }

  Future<List<Polygon>> _fetchRegenciesAndLoadPolygons(String provinceId) async {
    List<Polygon> allRegencyPolygons = [];
    List<Marker> newMarkers = [];
    
    String basicAuth = 'Basic ${base64Encode(utf8.encode('aingExcel:machinegunkelly'))}';

    try {
      final response = await http.get(
        Uri.parse('https://geopas.satgasprr.go.id/api/excel/wilayah/2/$provinceId'),
        headers: {'Authorization': basicAuth},
      );

      if (response.statusCode == 200) {
        List<dynamic> regencies = json.decode(response.body);

        for (var regency in regencies) {
          final String kode = regency['kode'];
          final String kondisi = regency['kondisi'].toString().trim();
          final String nama = regency['nama'];
          final double lat = double.parse(regency['latitude']);
          final double lon = double.parse(regency['longitude']);

          final polygons = await _parseGeoJson(
            'assets/mapdata/$kode.geojson', 
            kondisi
          );
          
          allRegencyPolygons.addAll(polygons);

          newMarkers.add(
            Marker(
              point: LatLng(lat, lon),
              width: 120, height: 40,
              child: IgnorePointer(
                child: Text(
                  nama.replaceAll('\n', ' '),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 3, color: Colors.black)],
                  ),
                ),
              ),
            ),
          );
        }
        
        setState(() {
          _regencyMarkers = newMarkers;
        });
      }
    } catch (e) {
      debugPrint("API Error: $e");
    }
    return allRegencyPolygons;
  }

  Future<List<Polygon>> _parseGeoJson(String path, String kondisi) async {
    Color currentRegencyColor;
    Color currentRegencyBorderColor;
    if (kondisi == 'Normal') {
      currentRegencyColor = const Color(0xFF00A042).withOpacity(0.4);
      currentRegencyBorderColor = const Color(0xFF00A042).withOpacity(0.8);
    } else if (kondisi == 'Atensi') {
      currentRegencyColor = const Color(0xFF998000).withOpacity(0.6);
      currentRegencyBorderColor = const Color(0xFF998000).withOpacity(0.8);
    } else if (kondisi == 'Mendekati Normal') {
      currentRegencyColor = const Color(0xFF0030B3).withOpacity(0.6);
      currentRegencyBorderColor = const Color(0xFF0030B3).withOpacity(0.8);
    }  else if (kondisi == 'Provinsi') {
      currentRegencyColor = const Color(0xFFFFFFFF).withOpacity(0.1);
      currentRegencyBorderColor = const Color(0xFFFFFFFF).withOpacity(0.8);
    } else {
      currentRegencyColor = const Color(0xFF00A042).withOpacity(0);
      currentRegencyBorderColor = const Color(0xFF00A042).withOpacity(0.8);
    }
    debugPrint(kondisi);
    debugPrint(currentRegencyColor.toString());

    List<Polygon> polys = [];
    try {
      String geoJsonString = await rootBundle.loadString(path);
      final Map<String, dynamic> data = json.decode(geoJsonString);

      for (var feature in data['features']) {
        var geometry = feature['geometry'];
        
        if (geometry['type'] == 'Polygon') {
          polys.add(_createPolygon(geometry['coordinates'], currentRegencyColor, currentRegencyBorderColor));
        } else if (geometry['type'] == 'MultiPolygon') {
          for (var polyCoords in geometry['coordinates']) {
            polys.add(_createPolygon(polyCoords, currentRegencyColor, currentRegencyBorderColor));
          }
        }
      }
    } catch (e) {
      debugPrint("File Error $path: $e");
    }
    return polys;
  }

  Polygon _createPolygon(List<dynamic> rings, Color fill, Color border) {
    List<LatLng> points = [];
    for (var coord in rings[0]) {
      points.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
    }

    return Polygon(
      points: points,
      color: fill, 
      //borderColor: Colors.white,
      borderColor: border,
      borderStrokeWidth: 1.0,
      isFilled: true,
    );
  }

  String? _getProvinceAtPoint(LatLng point) {
    for (var entry in MapData.provinceCenters.entries) {
      double distance = const Distance().as(LengthUnit.Kilometer, point, entry.value);
      if (distance < 150) return entry.key;
    }
    return null;
  }

  void _onAreaClicked(String id) {
    setState(() {
      _selectedProvinceId = id;
      _polygonFuture = _fetchRegenciesAndLoadPolygons(id);
    });
    final center = MapData.provinceCenters[id];
    if (center != null) _mapController.move(center, 8.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(flex: 10, child: Align(alignment: Alignment.centerLeft, child: Image.asset('assets/images/logo.png', height: 42))),
            Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/logo2.png', height: 42),
                const SizedBox(width: 14),
                Image.asset('assets/images/icon-info.png', height: 20),
              ],
            ))),
          ],
        ),
      ),
      body: MouseRegion(
        cursor: _isHandCursor ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: FutureBuilder<List<Polygon>>(
          future: _polygonFuture,
          builder: (context, snapshot) {
            return FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(1.5000, 99.0000),
                initialZoom: 7.0,
                onTap: (tapPosition, point) {
                  final id = _getProvinceAtPoint(point);
                  if (id != null && _selectedProvinceId == null) _onAreaClicked(id);
                },
                onPointerHover: (event, point) {
                  final id = _getProvinceAtPoint(point);
                  bool hover = (id != null && _selectedProvinceId == null);
                  if (hover != _isHandCursor) setState(() => _isHandCursor = hover);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                ),
                if (snapshot.hasData) PolygonLayer(polygons: snapshot.data!),
                
                MarkerLayer(
                  markers: _selectedProvinceId == null 
                    ? MapData.provinceCenters.entries.map((entry) {
                        return Marker(
                          point: entry.value,
                          width: 150, height: 30,
                          child: IgnorePointer(
                            child: Text(
                              MapData.provinceNames[entry.key]!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, shadows: [Shadow(blurRadius: 3, color: Colors.black)]),
                            ),
                          ),
                        );
                      }).toList()
                    : _regencyMarkers,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
