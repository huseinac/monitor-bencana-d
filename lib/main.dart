import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:http/http.dart' as http;
import 'mapdata/map_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final Directory cacheDirectory = await getTemporaryDirectory();
  final hiveCacheStore = HiveCacheStore(
    cacheDirectory.path,
    hiveBoxName: 'map_tiles_cache',
  );
  runApp(MyApp(cacheStore: hiveCacheStore));
}

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

class MyApp extends StatelessWidget {
  final HiveCacheStore cacheStore;
  const MyApp({super.key, required this.cacheStore});
  static const Color brandBlue = Color(0xFF22467a);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitor Bencana',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: brandBlue, primary: brandBlue),
        appBarTheme: const AppBarTheme(
            backgroundColor: brandBlue, foregroundColor: Colors.white, elevation: 0),
      ),
      debugShowCheckedModeBanner: false,
      home: MyHomePage(title: 'Monitor Bencana', cacheStore: cacheStore),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final HiveCacheStore cacheStore;
  const MyHomePage({super.key, required this.title, required this.cacheStore});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final MapController _mapController = MapController();
  final ScrollController _panelScrollController = ScrollController();

  List<ClickablePolygon> _activePolygons = [];
  String? _selectedProvinceId;
  String? _selectedRegencyId;
  String? _hoveredCode;
  int _currentLevel = 1;
  List<Marker> _currentMarkers = [];
  bool _isLoading = false;
  String _showMonitorButton = '';
  bool _isShowMonitorWilayahPanel = false;
  bool _isShowUpdatePanel = false;
  bool _isShowPekerjaanPanel = false;
  bool _isShowTkdPanel = false;

  String? _selectedOptionProv;
  final Map<String, String> _optionProvinces = {
    '0': 'All',
    '11': 'Aceh',
    '12': 'Sumatera Utara',
    '13': 'Sumatera Barat',
  };

  String? _selectedOptionKabupaten = '';
  String? _selectedOptionKecamatan = '';
  List<Map<String, dynamic>> _panelWilayahOptionalData = [];
  int _panelWilayahCounterNormal = 0;
  int _panelWilayahCounterMendekati = 0;
  int _panelWilayahCounterAtensi = 0;

  Future<void> _loadWilayahPanelData(String parentCode, String parentName) async {
    try {
      setState(() {
        _isLoading = true;
        _currentLevel += 1;
      });

      String auth = 'Basic ${base64Encode(utf8.encode('aingExcel:machinegunkelly'))}';
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/excel/wilayah/${_currentLevel == 4 ? 3 : _currentLevel}/$parentCode'),
        headers: {'Authorization': auth},
      );

      if (response.statusCode == 200) {
        List<dynamic> areas = json.decode(response.body);
        setState(() {
          // 1. Clear old data so previous regencies don't stick around
          _panelWilayahOptionalData.clear();
          _panelWilayahCounterNormal = 0;
          _panelWilayahCounterMendekati = 0;
          _panelWilayahCounterAtensi = 0;
          
          // 2. Add 'All' option if needed, similar to your provinces
          _panelWilayahOptionalData.add({
            'kode': '0',
            'nama': 'All',
            'kondisi': 'Normal'
          });

          for (var area in areas) {
            if (area['kondisi'] == 'Normal') {
              _panelWilayahCounterNormal += 1;
            } else if(area['kondisi'] == 'Mendekati') {
              _panelWilayahCounterMendekati += 1;
            } else if(area['kondisi'] == 'Atensi') {
              _panelWilayahCounterAtensi += 1;
            } else {
              _panelWilayahCounterNormal += 1;
            }

            _panelWilayahOptionalData.add({
              'kode': area['kode'].toString(),
              'nama': area['nama'].toString(),
              'kondisi': area['kondisi']?.toString() ?? 'Normal',
            });
          }
        });  

        switch (_currentLevel) {
          case 3:
            setState(() {
              _selectedOptionKabupaten = parentName;
              _selectedRegencyId = parentCode;
            });
          break;

          case 4:
            debugPrint('asdasd');
            setState(() {
              _selectedOptionKecamatan = parentName;
            });
          break;

          default:
        }

        _fetchWilayahData(_currentLevel, parentCode);

        debugPrint('level now'+_currentLevel.toString());

      } else {
        throw Exception();
      }
    } catch (e) {
      _showErrorSnippet("Gagal mengambil data Level $_currentLevel.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _rightPanelToggle() {
    setState(() {
      _isShowMonitorWilayahPanel = _showMonitorButton == 'wilayah';
      _isShowUpdatePanel = _showMonitorButton == 'update';
      _isShowPekerjaanPanel = _showMonitorButton == 'pekerjaan';
      _isShowTkdPanel = _showMonitorButton == 'tkd';
      _showMonitorButton = '';
    });
  }

  // --- Helper UI Methods ---

  Widget _buildSidebarButton({
    required String imagePath,
    required String label,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 90,
          height: 90,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: const Color(0xFF2D1F0B),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.withOpacity(0.5))),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(imagePath, width: 30, height: 30, fit: BoxFit.contain),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanelDropdown({
    required String hint,
    required String? value,
    required Map<String, String> items, // Changed to Map
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      height: 35,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          dropdownColor: const Color(0xFF211505),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          // Iterate through Map entries
          items: items.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,   // This is the ID (e.g., '11')
              child: Text(entry.value), // This is the Label (e.g., 'Aceh')
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildChecklistItem(String label, String kondisi, String kode) {
    Color indikatorColor;
    switch (kondisi) {
      case "Mendekati":
        indikatorColor = Color(0xFF0030B3);
      break;

      case 'Atensi':
        indikatorColor = Color(0xFF998000);
      break;

      default:
        indikatorColor = Color(0xFF00A042);
    }
    return 
    MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: GestureDetector(
          onTap: () => _loadWilayahPanelData(kode, label),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: indikatorColor,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: Colors.white24),
                ),
              ),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),

      )
    );
  }

  // --- Logic Methods ---

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    _currentLevel = 1;
    List<ClickablePolygon> all = [];
    final List<String> codes = ['11', '12', '13'];

    for (String code in codes) {
      final data =
          await _parseGeoJson('assets/mapdata/$code.geojson', 'Provinsi', code);
      all.addAll(data);
    }
    setState(() {
      _activePolygons = all;
      _isLoading = false;
    });
  }

  Future<void> _fetchWilayahData(int level, String parentCode) async {
    setState(() => _isLoading = true);
    _currentLevel = level;

    List<ClickablePolygon> newPolys = [];
    List<Marker> newMarkers = [];
    bool hasMissingFiles = false;

    String auth = 'Basic ${base64Encode(utf8.encode('aingExcel:machinegunkelly'))}';

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/excel/wilayah/${level == 4 ? 3 : level}/$parentCode'),
        headers: {'Authorization': auth},
      );

      if (response.statusCode == 200) {
        List<dynamic> areas = json.decode(response.body);

        for (var area in areas) {
          final String kode = area['kode'];
          final String kondisi = area['kondisi']?.toString().trim() ?? 'Normal';
          final String nama = area['nama'] ?? 'Unknown';

          try {
            final List<ClickablePolygon> geoData =
                await _parseGeoJson('assets/mapdata/$kode.geojson', kondisi, kode);

            if (geoData.isNotEmpty) {
              newPolys.addAll(geoData);
              LatLng centerPoint = geoData.first.center;
              newMarkers.add(
                Marker(
                  point: centerPoint,
                  width: 120,
                  height: 40,
                  child: IgnorePointer(
                    child: Text(
                      nama.replaceAll('\n', ' '),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: level >= 3 ? 8 : 10,
                        fontWeight: FontWeight.bold,
                        shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
                      ),
                    ),
                  ),
                ),
              );
            }
          } catch (e) {
            hasMissingFiles = true;
          }
        }

        if (hasMissingFiles) {
          _showErrorSnippet("Beberapa data peta sub-distrik tidak ditemukan.");
        }
      }
    } catch (e) {
      _showErrorSnippet("Gagal mengambil data Level $level.");
    } finally {
      setState(() {
        _activePolygons = newPolys;
        _currentMarkers = newMarkers;
        _isLoading = false;
      });
    }
  }

  void _onAreaClicked(String code, LatLng center) {
    debugPrint(center.toString());
    if (_currentLevel == 1) {
      _selectedProvinceId = code;
      _fetchWilayahData(2, code);
      _mapController.move(center, 8.5);
    } else if (_currentLevel == 2) {
      _selectedRegencyId = code;
      _fetchWilayahData(3, code);
      _mapController.move(center, 11.0);
    } else if (_currentLevel == 3) {
      _fetchWilayahData(4, code);
      _mapController.move(center, 13.5);
    }
  }

  void _goBack() {
    if (_currentLevel == 4) {
      _fetchWilayahData(3, _selectedRegencyId!);
    } else if (_currentLevel == 3) {
      _selectedRegencyId = null;
      _fetchWilayahData(2, _selectedProvinceId!);
    } else if (_currentLevel == 2) {
      _selectedProvinceId = null;
      _selectedOptionKabupaten = '';
      _selectedOptionKecamatan = '';
      _panelWilayahOptionalData.clear();

      _currentMarkers = [];
      _loadInitialData();
      _mapController.move(const LatLng(1.5000, 99.0000), 7.0);
    }
  }

  void _handleMapTap(LatLng point) {
    for (int i = _activePolygons.length - 1; i >= 0; i--) {
      final cp = _activePolygons[i];
      if (_isPointInPolygon(point, cp.polygon.points)) {
        _onAreaClicked(cp.code, cp.center);
        return;
      }
    }
  }

  void _showErrorSnippet(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> vertices) {
    int i, j = vertices.length - 1;
    bool oddNodes = false;
    double x = point.longitude;
    double y = point.latitude;
    for (i = 0; i < vertices.length; i++) {
      if ((vertices[i].latitude < y && vertices[j].latitude >= y ||
              vertices[j].latitude < y && vertices[i].latitude >= y) &&
          (vertices[i].longitude <= x || vertices[j].longitude <= x)) {
        if (vertices[i].longitude +
                (y - vertices[i].latitude) /
                    (vertices[j].latitude - vertices[i].latitude) *
                    (vertices[j].longitude - vertices[i].longitude) <
            x) {
          oddNodes = !oddNodes;
        }
      }
      j = i;
    }
    return oddNodes;
  }

  Future<List<ClickablePolygon>> _parseGeoJson(
      String path, String kondisi, String areaCode) async {
    List<ClickablePolygon> results = [];
    String content = await rootBundle.loadString(path);
    final data = json.decode(content);

    for (var feature in data['features']) {
      var geom = feature['geometry'];
      List<dynamic> coordsList =
          geom['type'] == 'Polygon' ? [geom['coordinates']] : geom['coordinates'];

      for (var polyCoords in coordsList) {
        List<LatLng> points = (polyCoords[0] as List)
            .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
            .toList();

        double sumLat = 0, sumLon = 0;
        for (var p in points) {
          sumLat += p.latitude;
          sumLon += p.longitude;
        }

        results.add(ClickablePolygon(
          polygon: Polygon(
              points: points,
              isFilled: true,
              color: Colors.transparent,
              borderColor: Colors.transparent),
          code: areaCode,
          center: LatLng(sumLat / points.length, sumLon / points.length),
          kondisi: kondisi,
        ));
      }
    }
    return results;
  }

  Color _getColor(String kondisi, bool isFill, bool isHovered) {
    double op = isFill ? (isHovered ? 0.75 : 0.4) : (isHovered ? 1.0 : 0.8);
    switch (kondisi) {
      case 'Normal':
        return const Color(0xFF00A042).withOpacity(op);
      case 'Atensi':
        return const Color(0xFF998000).withOpacity(op);
      case 'Mendekati Normal':
        return const Color(0xFF0030B3).withOpacity(op);
      case 'Provinsi':
        return Colors.white.withOpacity(isHovered ? 0.8 : 0.2);
      default:
        return isFill ? Colors.transparent : Colors.grey.withOpacity(op);
    }
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
                    child: Image.asset('assets/images/logo.png', height: 42))),
            Image.asset('assets/images/logo2.png', height: 42),
          ],
        ),
      ),
      body: Stack(
        children: [
          // 1. The Map Layer (Wrapped in RepaintBoundary)
          Positioned.fill(
            child: RepaintBoundary(
              child: MouseRegion(
                cursor: _hoveredCode != null
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(1.5000, 99.0000),
                    initialZoom: 7.0,
                    onTap: (tapPos, point) => _handleMapTap(point),
                    onPointerHover: (event, point) {
                      String? hitCode;
                      for (var cp in _activePolygons) {
                        if (_isPointInPolygon(point, cp.polygon.points)) {
                          hitCode = cp.code;
                          break;
                        }
                      }
                      if (hitCode != _hoveredCode) {
                        setState(() => _hoveredCode = hitCode);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                      tileProvider: CachedTileProvider(store: widget.cacheStore),
                    ),
                    PolygonLayer(
                      polygons: _activePolygons.map((cp) {
                        final isHovered = cp.code == _hoveredCode;
                        return Polygon(
                          points: cp.polygon.points,
                          isFilled: true,
                          color: _getColor(cp.kondisi, true, isHovered),
                          borderColor: _getColor(cp.kondisi, false, isHovered),
                          borderStrokeWidth: isHovered ? 2.5 : 1.0,
                        );
                      }).toList(),
                    ),
                    MarkerLayer(
                      markers: _currentLevel == 1
                          ? MapData.provinceCenters.entries
                              .map((e) => Marker(
                                    point: e.value,
                                    width: 150,
                                    height: 30,
                                    child: IgnorePointer(
                                        child: Text(MapData.provinceNames[e.key]!,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                shadows: [
                                                  Shadow(
                                                      blurRadius: 3,
                                                      color: Colors.black)
                                                ]))),
                                  ))
                              .toList()
                          : _currentMarkers,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Sidebar (Wrapped in RepaintBoundary)
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: RepaintBoundary(
              child: SizedBox(
                width: 150,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSidebarButton(
                      imagePath: 'assets/images/wilayah.png',
                      label: "Wilayah",
                      onTap: () => setState(() => _showMonitorButton = 'wilayah'),
                    ),
                    const SizedBox(height: 16),
                    _buildSidebarButton(
                      imagePath: 'assets/images/indikator.png',
                      label: "Update kondisi (Indikator)",
                      onTap: () => setState(() => _showMonitorButton = 'update'),
                    ),
                    const SizedBox(height: 16),
                    _buildSidebarButton(
                      imagePath: 'assets/images/pekerjaan.png',
                      label: "DalRenduk",
                      onTap: () => setState(() => _showMonitorButton = 'pekerjaan'),
                    ),
                    const SizedBox(height: 16),
                    _buildSidebarButton(
                      imagePath: 'assets/images/tkd.png',
                      label: "TKD",
                      onTap: () => setState(() => _showMonitorButton = 'tkd'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Floating "Kembali"
          if (_currentLevel > 1)
            Positioned(
              top: 20,
              left: 100,
              child: FloatingActionButton.extended(
                onPressed: _goBack,
                label: const Text("Kembali"),
                icon: const Icon(Icons.arrow_back),
                backgroundColor: MyApp.brandBlue,
                foregroundColor: Colors.white,
              ),
            ),

          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // 4. Panel Toggle Buttons
          Positioned(
            top: 10,
            right: 40,
            child: Stack(
              children: [
                if (_showMonitorButton.isNotEmpty)
                  MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _rightPanelToggle,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F200C),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.withOpacity(0.5)),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/database_${_showMonitorButton == 'wilayah' ? 'wilayah' : _showMonitorButton == 'update' ? 'indikator' : _showMonitorButton == 'pekerjaan' ? 'pekerjaan' : 'tkd'}.png',
                              width: 30,
                              height: 30,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      )),
              ],
            )
          ),

          // 5. Monitor Wilayah Panel
          if (_isShowMonitorWilayahPanel)
            Positioned(
              top: 10,
              right: 40,
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF211505).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            "Kondisi dan Progress Indikator Pemulihan Pemerintahan dan Kemasyarakatan yang Terdampak Bencana",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => _isShowMonitorWilayahPanel = false),
                          icon: const Icon(Icons.close,
                              color: Colors.white60, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPanelDropdown(
                            hint: "Prop :",
                            value: _selectedOptionProv,
                            items: _optionProvinces,
                            onChanged: (String? newId) {
                              setState(() {
                                _selectedOptionProv = newId;
                              });
                              
                              _currentLevel = 1;
                              _selectedOptionKabupaten = '';
                              _selectedOptionKecamatan = '';
                              if (newId != null && newId != 'All') {
                                _selectedProvinceId = newId;
                                _loadWilayahPanelData(newId, '');
                              } else {
                                _selectedProvinceId = null;
                                _currentMarkers = [];
                                _loadInitialData();
                                //_mapController.move(const LatLng(1.5000, 99.0000), 7.0);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 35,
                            color: Colors.white10,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text("$_selectedOptionKabupaten", style: TextStyle(color: Colors.white, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 35,
                            color: Colors.white10,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text("$_selectedOptionKecamatan", style: TextStyle(color: Colors.white, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLegendItem(Colors.green, "NORMAL : $_panelWilayahCounterNormal"),
                        _buildLegendItem(Colors.blue, "MENDEKATI NORMAL : $_panelWilayahCounterMendekati"),
                        _buildLegendItem(Colors.yellow[700]!, "ATENSI KHUSUS : $_panelWilayahCounterAtensi"),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 24),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          scrollbarTheme: ScrollbarThemeData(
                            thumbColor: WidgetStateProperty.all(Colors.white.withOpacity(0.5)), // White thumb
                            trackColor: WidgetStateProperty.all(Colors.white10), // Subtle white track
                            interactive: true,
                          ),
                        ),
                        child: Scrollbar(
                          controller: _panelScrollController,
                          thumbVisibility: true, // This makes the scrollbar always visible while scrolling
                          trackVisibility: true, // Optional: shows the track behind the thumb
                          thickness: 6.0,        // Adjust the width of the scrollbar
                          radius: const Radius.circular(10),
                          child: SingleChildScrollView(
                            controller: _panelScrollController,
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                if (_panelWilayahOptionalData.isEmpty || _panelWilayahOptionalData.length == 1)
                                  Column(
                                    children: [
                                      _buildChecklistItem("Aceh", '', '11'),
                                      _buildChecklistItem("Sumatera Utara", '', '12'),
                                      _buildChecklistItem("Sumatera Barat", '', '13')
                                    ],
                                  )
                                else
                                  // Loop through the Map entries
                                  ..._panelWilayahOptionalData
                                      .where((item) => item['kode'] != '0')
                                      .map((item) {
                                        return _buildChecklistItem(item['nama'], item['kondisi'], item['kode']);
                                      }).toList(),
                              ],
                            ),
                          ),
                        ),
                      )
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}