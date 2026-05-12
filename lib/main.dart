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
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';

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

  final String arcgisSatellite = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  final String arcgisDefault = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';

  late String _currentTileUrl;

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

  // Controller to fix the "No ScrollPosition attached" error from your screenshot
  final ScrollController _pekerjaanScrollController = ScrollController();
  int _selectedPekerjaanIndex = 0;

  //Widget _buildTableRow(int index) {
  //  return Container(
  //    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
  //    decoration: const BoxDecoration(
  //      border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
  //    ),
  //    child: Row(
  //      children: [
  //        Expanded(flex: 1, child: Text("$index", style: const TextStyle(color: Colors.white, fontSize: 11))),
  //        const Expanded(flex: 4, child: Text("Kab. Bireuen", style: TextStyle(color: Colors.white, fontSize: 11))),
  //        const Expanded(flex: 3, child: Text("Rp 12.500.000", style: TextStyle(color: Colors.cyanAccent, fontSize: 11))),
  //        const Expanded(flex: 2, child: Text("85%", style: TextStyle(color: Colors.white, fontSize: 11))),
  //      ],
  //    ),
  //  );
  //}

  Widget _buildPekerjaanHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Ringkasan Paket Pekerjaan Penanganan Bencana Sumatra dan Aceh",
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => setState(() => _isShowPekerjaanPanel = false),
              ),
            ],
          ),
          const Text("Ringkasan jenis paket pekerjaan di Sumatera dan Aceh", 
              style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _buildPanelDropdown(hint: "Prop :", value: _selectedOptionProv, items: _optionProvinces, onChanged: (v) => setState(() {
                _selectedOptionProv = v;
                _fetchWilayahData(2, v.toString());
                _fetchPekerjaanSummary(v.toString());
              }))),
              //const SizedBox(width: 10),
              //Expanded(child: _buildPanelDropdown(hint: "Kec :", value: null, items: {'0': 'Semua'}, onChanged: (v) {})),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white10),
        ],
      ),
    );
  }

  Widget _buildPekerjaanList() {
    return ListView.separated(
      controller: _pekerjaanScrollController,
      itemCount: _pekerjaanData.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final header = _pekerjaanData[index];
        final List listPekerjaan = header['list_pekerjaan'] ?? [];
        
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
          onTap: () => setState(() => _selectedPekerjaanIndex = index),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "${index + 1}. ${header['nama']}",
                        style: const TextStyle(color: Colors.white, fontSize: 11)
                      )
                    ),
                    Text(
                      "${header['persentase']}% | ${listPekerjaan.length} Pekerjaan",
                      style: const TextStyle(color: Colors.white, fontSize: 10)
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: (header['persentase'] as num).toDouble() / 100,
                  backgroundColor: Colors.white10,
                  color: listPekerjaan.isNotEmpty ? const Color(0xFF996600) : Colors.transparent,
                  minHeight: 3,
                ),
              ],
            ),
          )
        );
      },
    );
  }

  Widget _buildPekerjaanDetail() {
    if (_pekerjaanData.isEmpty) return const SizedBox();

    final selectedHeader = _pekerjaanData[_selectedPekerjaanIndex];
    final List listPekerjaan = selectedHeader['list_pekerjaan'] ?? [];

    if (listPekerjaan.isEmpty) {
      return const Center(
        child: Text("Tidak ada rincian pekerjaan", style: TextStyle(color: Colors.white24))
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: listPekerjaan.length,
      itemBuilder: (context, index) {
        final detail = listPekerjaan[index];
        return Card(
          color: Colors.white.withOpacity(0.05),
          margin: const EdgeInsets.only(bottom: 15),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.engineering, color: Colors.cyanAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        detail['nama'] ?? "Tanpa Nama",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildDetailRow("Program", detail['nama_program']),
                _buildDetailRow("Nilai Kontrak", "Rp ${detail['nilai_kontrak']}"),
                _buildDetailRow("Lokasi", detail['wilayah']['nama']),
                const SizedBox(height: 10),
                Text(
                  "Progres: ${detail['persentase']}%",
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper untuk baris detail
  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text("$label: ${value ?? '-'}", 
        style: const TextStyle(color: Colors.white70, fontSize: 11)),
    );
  }

  final PopupController _popupLayerController = PopupController();
  Map<String, dynamic>? _selectedProjectDetail;
  bool _isShowProjectDetailPanel = false;

  Widget _buildMarkerPopup(Marker marker) {
    // Extract the project data we stored in the Key
    final project = (marker.key as ValueKey).value as Map<String, dynamic>;

    return Container(
      width: 300,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black54)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project['wilayah']['nama'] ?? "Lokasi",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const Divider(color: Colors.white24),
          Text(
            project['nama'] ?? "Nama Pekerjaan",
            style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Nominal:", style: TextStyle(color: Colors.white70, fontSize: 11)),
              Text("Rp ${project['nominal']}", style: const TextStyle(color: Colors.white, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _popupBtn("Detail", () {
                setState(() {
                  _selectedProjectDetail = project;
                  _isShowProjectDetailPanel = true;
                  //_popupLayerController.hideAllPopups(); // Close the small popup
                });
              }),
              const SizedBox(width: 5),
              _popupBtn("Peta", () {}),
              const SizedBox(width: 5),
              _popupBtn("Streetview", () {}),
            ],
          )
        ],
      ),
    );
  }

  Widget _popupBtn(String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF22467A),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
          ),
        ),
      ),
    );
  }

  // Ubah dari List<Map<String, dynamic>> menjadi List<dynamic>
  List<dynamic> _pekerjaanData = [];
  List<Marker> _pekerjaanMarkers = [];

  Future<void> _fetchPekerjaanSummary(String kode) async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('https://geopas.satgasprr.go.id/map/get_pekerjaan?wilayah_kode=$kode'),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<Marker> newMarkers = [];

        for (var agency in data) {
          // Access the nested "list_pekerjaan" array
          List<dynamic> projects = agency['list_pekerjaan'] ?? [];
          
          for (var project in projects) {
            double? lat = double.tryParse(project['latitude']?.toString() ?? '');
            double? lng = double.tryParse(project['longitude']?.toString() ?? '');

            if (lat != null && lng != null) {
              // 1. Get the category ID from the JSON
              int categoryId = project['kategori_paket_pekerjaan_id'] ?? 0;

              // 2. Determine the image path based on the ID
              String markerImage;
              switch (categoryId) {
                case 1:
                  markerImage = 'building-yellow.png';
                break;
                case 2:
                  markerImage = 'bride-yellow.png';
                break;
                case 3:
                  markerImage = 'home-yellow.png';
                break;
                case 4:
                  markerImage = 'homes-yellow.png';
                break;
                case 5:
                  markerImage = 'school-yellow.png';
                break;
                case 6:
                  markerImage = 'religion-yellow.png';
                break;
                case 7:
                  markerImage = 'help-yellow.png';
                break;
                case 8:
                  markerImage = 'health-yellow.png';
                break;
                case 9:
                  markerImage = 'school-yellow.png';
                break;
                case 10:
                  markerImage = 'road-yellow.png';
                break;
                case 11:
                  markerImage = 'store-yellow.png';
                break;
                case 12:
                  markerImage = 'store-yellow.png';
                break;
                case 13:
                  markerImage = 'building-yellow.png';
                break;
                case 14:
                  markerImage = 'river-yellow.png';
                break;
                case 15:
                  markerImage = 'river-yellow.png';
                break;
                case 16:
                  markerImage = 'water-yellow.png';
                break;
                case 17:
                  markerImage = 'gas_station-yellow.png';
                break;
                case 18:
                  markerImage = 'homes-yellow.png';
                break;
                case 19:
                  markerImage = 'gas-yellow.png';
                break;
                case 20:
                  markerImage = 'help-yellow.png';
                break;
                case 21:
                  markerImage = 'electric-yellow.png';
                break;
                case 22:
                  markerImage = 'road-yellow.png';
                break;
                case 23:
                  markerImage = 'road-yellow.png';
                break;
                case 24:
                  markerImage = 'road-yellow.png';
                break;
                case 25:
                  markerImage = 'road-yellow.png';
                break;
                case 26:
                  markerImage = 'river-yellow.png';
                break;
                default:
                  markerImage = 'help-yellow.png';
              }

              // Inside _fetchPekerjaanSummary, update how markers are added:
              newMarkers.add(
                Marker(
                  point: LatLng(lat, lng),
                  width: 40,
                  height: 40,
                  // Add a key or store the data in the marker for the popup to read
                  key: ValueKey(project), 
                  child: Image.asset(
                    'assets/images/$markerImage',
                    fit: BoxFit.contain,
                  ),
                ),
              );
            }
          }
        }

        setState(() {
          _pekerjaanData = List<Map<String, dynamic>>.from(data);
          _pekerjaanMarkers = newMarkers; 
          _selectedPekerjaanIndex = 0;
        });
      }
    } catch (e) {
      debugPrint("Marker fetch error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

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

  Widget _buildDataRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label, style: const TextStyle(color: Colors.white70))),
          const Text(":  ", style: TextStyle(color: Colors.white70)),
          Expanded(child: Text(value?.toString() ?? "-", style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(String title, {bool isActive = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        // Highlight the active tab with the brand blue or a dark wood tone
        color: isActive ? const Color(0xFF22467A) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // Small indicator dot for active items
          if (isActive)
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.cyanAccent,
                shape: BoxShape.circle,
              ),
            ),
          if (isActive) const SizedBox(width: 10),
          
          Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white60,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentTileUrl = arcgisSatellite;
    _loadInitialData();
  }

  void _rightPanelToggle() {
    if(_showMonitorButton == 'pekerjaan'){
      _fetchPekerjaanSummary('');
    }

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
        return Colors.white.withOpacity(isHovered ? 0.8 : 0.5);
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
                      urlTemplate: _currentTileUrl,
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
                          borderStrokeWidth: isHovered ? 4 : 2,
                        );
                      }).toList(),
                    ),
                    MarkerLayer(
                      markers: [
                        // Use 'if' inside the list combined with the spread operator '...'
                        if (_currentLevel == 1)
                          ...MapData.provinceCenters.entries
                              .map((e) => Marker(
                                    point: e.value,
                                    width: 150,
                                    height: 30,
                                    child: IgnorePointer(
                                      child: Text(
                                        MapData.provinceNames[e.key]!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          shadows: [
                                            Shadow(blurRadius: 3, color: Colors.black)
                                          ],
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList()
                        else
                          ..._currentMarkers, // Spread the list of current markers
                          
                        ..._pekerjaanMarkers, // Spread the API markers
                      ],
                    ),
                    PopupMarkerLayer(
                      options: PopupMarkerLayerOptions(
                        popupController: _popupLayerController,
                        markers: _pekerjaanMarkers, // Your existing list of markers
                        popupDisplayOptions: PopupDisplayOptions(
                          builder: (BuildContext context, Marker marker) {
                            // Find the project data associated with this marker
                            // You might need to store project data inside the Marker's 'key' or a Map
                            return _buildMarkerPopup(marker);
                          },
                        ),
                      ),
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
                      onTap: () => setState(() {
                        _currentTileUrl = arcgisSatellite;
                        _showMonitorButton = 'wilayah';
                      }),
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
                      onTap: () => setState(() {
                        _currentTileUrl = arcgisDefault;
                        _showMonitorButton = 'pekerjaan'; 
                        _fetchPekerjaanSummary('');
                        //_rightPanelToggle();
                      }),
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
            const Center(child: CircularProgressIndicator(color: Colors.green)),

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
                    )
                  ),
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
          
          if (_isShowPekerjaanPanel)
            Positioned(
              right: 20,
              top: 20,
              bottom: 20,
              child: Container(
                width: 650,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1208).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    // Header Section
                    _buildPekerjaanHeader(),
                    
                    // Main Content
                    Expanded(
                      child: Row(
                        children: [
                          // Left: Scrollable List
                          Expanded(flex: 4, child: _buildPekerjaanList()),
                          
                          // Vertical Divider
                          Container(width: 1, color: Colors.white10),
                          
                          // Right: Detailed View
                          Expanded(flex: 5, child: _buildPekerjaanDetail()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_isShowProjectDetailPanel && _selectedProjectDetail != null)
              Positioned(
                top: 20,
                right: 40,
                bottom: 20,
                child: Container(
                  width: 700, // Large panel width as shown in image
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1208).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      // Left Sidebar (Navigation)
                      Container(
                        width: 180,
                        padding: const EdgeInsets.all(15),
                        color: Colors.black26,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_selectedProjectDetail!['nama'] ?? '-', 
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            _buildSidebarItem("Informasi", isActive: true),
                            _buildSidebarItem("Penyedia"),
                            _buildSidebarItem("Rincian"),
                            // Add other menu items...
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- STICKY HEADER (Does not scroll) ---
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Informasi Paket Pekerjaan",
                                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () => setState(() => _isShowProjectDetailPanel = false),
                                  )
                                ],
                              ),
                              const Divider(color: Colors.white24),

                              // --- SCROLLABLE CONTENT ---
                              Expanded(
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                    scrollbarTheme: ScrollbarThemeData(
                                      thumbColor: WidgetStateProperty.all(Colors.white.withOpacity(0.5)),
                                      trackColor: WidgetStateProperty.all(Colors.white10),
                                      interactive: true,
                                    ),
                                  ),
                                  child: Scrollbar(
                                    thumbVisibility: true,
                                    thickness: 6.0,
                                    radius: const Radius.circular(10),
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildDataRow("Tahun Anggaran", _selectedProjectDetail?['tahun_anggaran'] ?? '-'),
                                          _buildDataRow("Nama Paket", _selectedProjectDetail?['nama'] ?? '-'),
                                          _buildDataRow("Program", _selectedProjectDetail?['nama_program'] ?? '-'),
                                          _buildDataRow("Kegiatan / Sub", _selectedProjectDetail?['nama_kegiatan'] ?? '-'),
                                          _buildDataRow("Kategori", _selectedProjectDetail?['kategori_paket_pekerjaan']?['nama'] ?? '-'),
                                          _buildDataRow("Indikator", _selectedProjectDetail?['indikator']?['nama'] ?? '-'),
                                          _buildDataRow("Wilayah", _selectedProjectDetail?['wilayah']?['nama'] ?? '-'),
                                          _buildDataRow("Koordinat", "${_selectedProjectDetail?['latitude'] ?? '0'}, ${_selectedProjectDetail?['longitude'] ?? '0'}"),
                                          
                                          const SizedBox(height: 20),
                                          const Text("Informasi Pengadaan",
                                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                          const Divider(color: Colors.white24),
                                          
                                          _buildDataRow("Nilai pagu", _selectedProjectDetail?['nilai_pagu'] ?? '0'),
                                          _buildDataRow("Nilai kontrak", _selectedProjectDetail?['nilai_kontrak'] ?? '0'),
                                          _buildDataRow("Nama rekening", _selectedProjectDetail?['nama_rekening'] ?? '-'),
                                          _buildDataRow("Nama penyedia", _selectedProjectDetail?['penyedia'] ?? '-'),
                                          _buildDataRow("No. Kontrak", _selectedProjectDetail?['no_kontrak'] ?? '-'),
                                          _buildDataRow("Masa pelaksanaan", '${_selectedProjectDetail?['tgl_awal_kontrak'] ?? ""} s/d ${_selectedProjectDetail?['tgl_akhir_kontrak'] ?? ""}'),
                                          _buildDataRow("Keterangan", _selectedProjectDetail?['keterangan'] ?? '-'),
                                          const SizedBox(height: 20), // Extra space at bottom
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),

            if (_isShowTkdPanel)
              Positioned(
                top: 10,
                right: 40,
                bottom: 20,
                child: Container(
                  width: 700,
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
                              "Analisa Penyaluran Transfer Ke Daerah (TKD ) PROV dan Kabupaten/Kota Terdampak Bencana Sumatera dan Aceh",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _isShowTkdPanel = false),
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
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white10),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            children: [
                              // Table Header
                              Container(
                                color: Colors.white.withOpacity(0.05),
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                child: const Row(
                                  children: [
                                    Expanded(flex: 1, child: Text("No", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                                    Expanded(flex: 2, child: Text("Pemerintah daerah", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                                    Expanded(flex: 2, child: Text("TKD 2026", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                                    Expanded(flex: 2, child: Text("Penyesuaian TKD 2026", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                                    Expanded(flex: 2, child: Text("Total TKD 2026 setelah penyesuaian", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              ),
                              //Expanded(
                              //  child: SingleChildScrollView(
                              //    child: Column(
                              //      children: List.generate(10, (index) => _buildTableRow(index + 1)),
                              //    ),
                              //  ),
                              //),
                            ],
                          ),
                        ),
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