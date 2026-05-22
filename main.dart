import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:async';
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

class MapWatermarkPainter extends CustomPainter {
  final String text;
  MapWatermarkPainter({required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    
    const textStyle = TextStyle(
      color: Color(0x1AFFFFFF), 
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );

    
    const double stepX = 180;
    const double stepY = 120;

    for (double x = -50; x < size.width + 100; x += stepX) {
      for (double y = -50; y < size.height + 100; y += stepY) {
        canvas.save();
        
        
        canvas.translate(x, y);
        canvas.rotate(-0.785398); 

        textPainter.text = TextSpan(text: text, style: textStyle);
        textPainter.layout();
        textPainter.paint(canvas, Offset.zero);

        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

  
  List<Marker> _allIndikatorMarkersMasterList = [];
  List<Marker> _allPekerjaanMarkersMasterList = [];

  List<ClickablePolygon> _activePolygons = [];
  String? _selectedProvinceId;
  String? _selectedRegencyId;
  String? _hoveredCode;
  DateTime _lastHoverCheck = DateTime.now();
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

  final ScrollController _pekerjaanScrollController = ScrollController();
  int _selectedPekerjaanIndex = 0;

  List<dynamic> _indikatorData = [];
  List<Marker> _updatedIndikatorMarkers = [];

  List<Marker> _allTkdMarkersMasterList = [];
  List<Marker> _tkdMarkers = [];
  List<dynamic> _tkdData = [];

  Future<void> _fetchTkdData() async {
    setState(() {
      _isLoading = true;
      _tkdData.clear();
      _allTkdMarkersMasterList.clear();
      _tkdMarkers.clear();
    });

    String kodeWilayah = _selectedRegencyId ?? (_selectedProvinceId ?? "");
    String url = 'https://geopas.satgasprr.go.id/map/get_anggaran?wilayah_kode=$kodeWilayah';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<Marker> newMarkers = [];

        for (var item in data) {
          var wilayah = item['wilayah'];
          if (wilayah == null) continue;

          // Extracting latitude and longitude safely from the nested wilayah key
          double? lat = double.tryParse(wilayah['latitude']?.toString() ?? '');
          double? lng = double.tryParse(wilayah['longitude']?.toString() ?? '');

          if (lat != null && lng != null) {
            String kondisi = wilayah['kondisi']?.toString() ?? 'Normal';
            
            //String markerImage = 'building';
            //switch (kondisi) {
            //  case 'Atensi': markerImage += '-yellow.png'; break;
            //  case 'Mendekati': markerImage += '-blue.png'; break;
            //  default: markerImage += '-blue.png'; // Fallback default icon asset
            //}
            String markerImage = 'building.png';

            late final Marker tkdMarker;
            tkdMarker = Marker(
              point: LatLng(lat, lng),
              width: 45,
              height: 45,
              alignment: Alignment.topCenter,
              key: ValueKey(item),
              child: RepaintBoundary(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Assuming you use the same popup layering strategy as your indicators
                  onTap: () => _popupLayerController.togglePopup(tkdMarker),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.cyanAccent, width: 2.0),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/$markerImage',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => 
                          const Icon(Icons.account_balance_wallet, color: Colors.greenAccent, size: 30),
                    ),
                  ),
                ),
              ),
            );

            newMarkers.add(tkdMarker);
          }
        }

        setState(() {
          _tkdData = data;
          _allTkdMarkersMasterList = newMarkers;
          _pruneVisibleMarkers(); // Call immediately to draw markers onto your current view
        });
      } else {
        _showErrorSnippet("Gagal memuat data TKD (Status: ${response.statusCode})");
      }
    } catch (e) {
      debugPrint("TKD fetch error: $e");
      _showErrorSnippet("Terjadi kesalahan saat mengambil data Anggaran/TKD.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchIndikatorData() async {
    if ( (_selectedRegencyId ?? (_selectedProvinceId ?? "")) == '' ) {
      _showErrorSnippet("Mohon pilih wilayah terlebih dahulu");
      return;
    }

    setState(() {
      _isLoading = true;
      _indikatorData.clear();
      _allIndikatorMarkersMasterList.clear();
      _updatedIndikatorMarkers.clear();
    });

    String kodeWilayah = _selectedRegencyId ?? (_selectedProvinceId ?? "");
    String url = 'https://geopas.satgasprr.go.id/map/get_indikator?wilayah_kode=$kodeWilayah';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final receivePort = ReceivePort();

        await Isolate.spawn(
          parseIndikatorJsonIsolate,
          {
            'jsonString': response.body,
            'sendPort': receivePort.sendPort,
          },
        );

        
        List<dynamic> backloggedData = [];
        List<Marker> backloggedMarkers = [];
        
        
        DateTime lastUiUpdateTime = DateTime.now();
        Timer? periodicUpdateTimer;

        
        void flushBufferToUi() {
          if (backloggedMarkers.isNotEmpty) {
            setState(() {
              _indikatorData.addAll(backloggedData);
              
              
              _allIndikatorMarkersMasterList.addAll(backloggedMarkers);
              
              
              _pruneVisibleMarkers();
              
              if (_isLoading) _isLoading = false;
            });
            backloggedData.clear();
            backloggedMarkers.clear();
            lastUiUpdateTime = DateTime.now();
          }
        }

        
        periodicUpdateTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
          flushBufferToUi();
        });
        

        await for (var message in receivePort) {
          if (message == 'DONE') {
            periodicUpdateTimer.cancel();
            flushBufferToUi(); 
            receivePort.close();
            break;
          }

          if (message is Map && message.containsKey('isolate_error')) {
            periodicUpdateTimer.cancel();
            _showErrorSnippet("Error: ${message['isolate_error']}");
            receivePort.close();
            break;
          }

          if (message is List) {
            for (var sektor in message) {
              double lat = double.parse(sektor['latitude'].toString());
              double lng = double.parse(sektor['longitude'].toString());
              String markerImage = _getMarkerImageName(sektor);

              late final Marker uniqueMarker;
              uniqueMarker = Marker(
                point: LatLng(lat, lng),
                width: 45,
                height: 45,
                alignment: Alignment.topCenter,
                key: ValueKey(sektor),
                child: RepaintBoundary( 
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _popupLayerController.togglePopup(uniqueMarker),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.0),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Image.asset(
                        'assets/images/$markerImage',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.location_on, color: Colors.red, size: 35),
                      ),
                    ),
                  ),
                ),
              );

              backloggedData.add(sektor);
              backloggedMarkers.add(uniqueMarker);
            }

            
            if (DateTime.now().difference(lastUiUpdateTime).inMilliseconds > 250) {
              flushBufferToUi();
            }
          }
        }
      } else {
        _showErrorSnippet("Gagal memuat data indikator (Status: ${response.statusCode})");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Indikator fetch error: $e");
      _showErrorSnippet("Terjadi kesalahan saat mengambil data indikator.");
      setState(() => _isLoading = false);
    }
  }

  void _pruneVisibleMarkers() {
    
    if (_mapController.camera == null) return;

    
    final bounds = _mapController.camera.visibleBounds;
    
    
    
    final southWest = LatLng(bounds.southWest.latitude - 0.5, bounds.southWest.longitude - 0.5);
    final northEast = LatLng(bounds.northEast.latitude + 0.5, bounds.northEast.longitude + 0.5);

    setState(() {
      
      _updatedIndikatorMarkers = _allIndikatorMarkersMasterList.where((marker) {
        return marker.point.latitude >= southWest.latitude &&
               marker.point.latitude <= northEast.latitude &&
               marker.point.longitude >= southWest.longitude &&
               marker.point.longitude <= northEast.longitude;
      }).toList();

      _pekerjaanMarkers = _allPekerjaanMarkersMasterList.where((marker) {
        return marker.point.latitude >= southWest.latitude &&
               marker.point.latitude <= northEast.latitude &&
               marker.point.longitude >= southWest.longitude &&
               marker.point.longitude <= northEast.longitude;
      }).toList();

      _tkdMarkers = _allTkdMarkersMasterList.where((marker) {
        return marker.point.latitude >= southWest.latitude &&
               marker.point.latitude <= northEast.latitude &&
               marker.point.longitude >= southWest.longitude &&
               marker.point.longitude <= northEast.longitude;
      }).toList();
    });
  }

  String _getMarkerImageName(Map<String, dynamic> sektor) {
    String indicatorName = sektor['indikator']?['nama'] ?? '';
    String markerImage = 'help'; 

    if (indicatorName.contains('Kantor')) {
      markerImage = 'building';
    } else if (indicatorName.contains('Faskes')) {
      markerImage = 'health';
    } else if (['PAUD', 'TK', 'SD', 'SMP', 'SMA/SMK', 'Madrasah/Ponpes'].any(indicatorName.contains)) {
      markerImage = 'school';
    } else if (indicatorName.contains('Jalan')) {
      markerImage = 'road';
    } else if (indicatorName.contains('Jembatan')) {
      markerImage = 'bride';
    } else if (indicatorName.contains('Kelistrikan')) {
      markerImage = 'electric';
    } else if (indicatorName.contains('PDAM/SPAM')) {
      markerImage = 'water';
    } else if (indicatorName.contains('Gedung Rumah Ibadah')) {
      markerImage = 'religion';
    } else if (indicatorName.contains('Sungai')) {
      markerImage = 'river';
    } else if (['Huntara', 'Huntap'].any(indicatorName.contains)) {
      markerImage = 'home';
    } else if (indicatorName.contains('Pengungsian')) {
      markerImage = 'homes';
    } else if (['toko diluar pasar', 'Hotel/Penginapan'].any(indicatorName.contains)) {
      markerImage = 'building';
    } else if (indicatorName.contains('SPBU')) {
      markerImage = 'gas_station';
    } else if (indicatorName.contains('Gas LPG')) {
      markerImage = 'gas';
    } else if (['Gedung/Sarpras Pasar', 'Gedung/Sarpras Resto', 'Koperasi'].any(indicatorName.contains)) {
      markerImage = 'store';
    } else if (indicatorName.contains('INTERNET')) {
      markerImage = 'help';
    } else if (['Persawahan', 'Perikanan'].any(indicatorName.contains)) {
      markerImage = 'river';
    } else if (['Pembersihan lumpur', 'DTH'].any(indicatorName.contains)) {
      markerImage = 'help';
    }

    switch (sektor['status']) {
      case 'Atensi': markerImage += '-yellow'; break;
      case 'Mendekati':
      case 'Sedang ditangani': markerImage += '-blue'; break;
      case 'Belum ditangani': markerImage += '-red'; break;
    }

    return '$markerImage.png';
  }

  Widget _buildIndikatorPopup(Marker marker) {
    final sektor = (marker.key as ValueKey).value as Map<String, dynamic>;

    String namaSektor = sektor['nama_lokasi'] ?? 'Tanpa Nama';
    String namaIndikator = (sektor['indikator']?['nama'] ?? 'Indikator') + ' Terdampak Bencana';
    
    String wilayahInfo = 
    [
      sektor['wilayah']['parent']['parent']['nama'] ?? '',
      sektor['wilayah']['parent']['nama'] ?? '',
      sektor['wilayah']['nama'] ?? ''
    ].where((element) => element.isNotEmpty).join(' - ');
    
    if (wilayahInfo.isEmpty) {
      wilayahInfo = sektor['wilayah']?['nama'] ?? '-';
    }

    String kondisi = sektor['kondisi'] ?? '-';
    String status = sektor['status'] ?? '-';
    String kondisiAwal = sektor['kondisi_awal'] ?? '-';
    String keterangan = sektor['keterangan'] ?? '-';

    double persentasePulih = 0.0;
    var rawPersentase = sektor['persentase'];
    if (rawPersentase != null) {
      persentasePulih = double.tryParse(rawPersentase.toString()) ?? 0.0;
    }

    String markerImage = '';
    if (sektor['indikator']['nama'].contains('Kantor')) {
        markerImage = 'building';
    } else if (sektor['indikator']['nama'].contains('Faskes')) {
        markerImage = 'health';
    } else if (
        sektor['indikator']['nama'].contains('PAUD') ||
        sektor['indikator']['nama'].contains('TK') ||
        sektor['indikator']['nama'].contains('SD') ||
        sektor['indikator']['nama'].contains('SMP') ||
        sektor['indikator']['nama'].contains('SMA/SMK') ||
        sektor['indikator']['nama'].contains('Madrasah/Ponpes')
      ) {
        markerImage = 'school';
    } else if (sektor['indikator']['nama'].contains('Jalan')) {
        markerImage = 'road';
    } else if (sektor['indikator']['nama'].contains('Jembatan')) {
        markerImage = 'bride';
    } else if (sektor['indikator']['nama'].contains('Kelistrikan')) {
        markerImage = 'electric';
    } else if (sektor['indikator']['nama'].contains('PDAM/SPAM')) {
        markerImage = 'water';
    } else if (sektor['indikator']['nama'].contains('Gedung Rumah Ibadah')) {
        markerImage = 'religion';
    } else if (sektor['indikator']['nama'].contains('Sungai')) {
        markerImage = 'river';
    } else if (
        sektor['indikator']['nama'].contains('Huntara') ||
        sektor['indikator']['nama'].contains('Huntap')
      ) {
        markerImage = 'home';
    } else if (sektor['indikator']['nama'].contains('Pengungsian')) {
        markerImage = 'homes';
    } else if (
        sektor['indikator']['nama'].contains('toko diluar pasar') ||
        sektor['indikator']['nama'].contains('Hotel/Penginapan')
      ) {
        markerImage = 'building';
    } else if (sektor['indikator']['nama'].contains('SPBU')) {
        markerImage = 'gas_station';
    } else if (sektor['indikator']['nama'].contains('Gas LPG')) {
        markerImage = 'gas';
    } else if (
        sektor['indikator']['nama'].contains('Gedung/Sarpras Pasar') ||
        sektor['indikator']['nama'].contains('Gedung/Sarpras Resto/Warung/Kafe/kedai') ||
        sektor['indikator']['nama'].contains('Koperasi')
      ) {
        markerImage = 'store';
    } else if (sektor['indikator']['nama'].contains('INTERNET')) {
        markerImage = 'help';
    } else if (
        sektor['indikator']['nama'].contains('Persawahan') ||
        sektor['indikator']['nama'].contains('Perikanan (Tambak)')
      ) {
        markerImage = 'river';
    } else if (
        sektor['indikator']['nama'].contains('Pembersihan lumpur') ||
        sektor['indikator']['nama'].contains('DTH')
      ) {
        markerImage = 'help';
    }

    switch (sektor['status']) {
      case 'Atensi':
        markerImage += '-yellow';
      break;
      case 'Mendekati':
        markerImage += '-blue';
      break;
      case 'Sedang ditangani':
        markerImage += '-blue';
      break;
      case 'Belum ditangani':
        markerImage += '-red';
      break;
      default:
    }

    markerImage += '.png';

    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(blurRadius: 12, color: Colors.black, offset: Offset(0, 4))
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  namaSektor.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Persentase Pulih:", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(
                      "${persentasePulih.toStringAsFixed(0)}%",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: persentasePulih / 100,
                    backgroundColor: Colors.white10,
                    color: const Color(0xFF4CAF50),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/$markerImage',
                        width: 20,
                        height: 20,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.assignment, color: Colors.tealAccent, size: 20);
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          namaIndikator,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const Text("Belum Dilaporkan", style: TextStyle(color: Colors.white38, fontSize: 12)),
                      Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.2), size: 16),
                      const Text("Belum Dilaporkan", style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildMetaRow("Wilayah", wilayahInfo),
                _buildMetaRow("Kondisi", kondisi),
                _buildMetaRow("Status", status),
                _buildMetaRow("Kondisi Awal", kondisiAwal),
                _buildMetaRow("Keterangan", keterangan),
              ],
            ),
          ),
          Positioned(
            top: 4, 
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              tooltip: 'Tutup',
              onPressed: () {
                _popupLayerController.hideAllPopups();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label :", style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

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
          
          List<dynamic> projects = agency['list_pekerjaan'] ?? [];
          
          for (var project in projects) {
            double? lat = double.tryParse(project['latitude']?.toString() ?? '');
            double? lng = double.tryParse(project['longitude']?.toString() ?? '');

            if (lat != null && lng != null) {
              int categoryId = project['kategori_paket_pekerjaan_id'] ?? 0;

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

              newMarkers.add(
                Marker(
                  point: LatLng(lat, lng),
                  width: 40,
                  height: 40,
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
        Uri.parse('https://geopas.satgasprr.go.id/api/excel/wilayah/${_currentLevel == 4 ? 3 : _currentLevel}/$parentCode'),
        headers: {'Authorization': auth},
      );

      if (response.statusCode == 200) {
        List<dynamic> areas = json.decode(response.body);
        setState(() {
          _panelWilayahOptionalData.clear();
          _panelWilayahCounterNormal = 0;
          _panelWilayahCounterMendekati = 0;
          _panelWilayahCounterAtensi = 0;
          
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
        
        color: isActive ? const Color(0xFF22467A) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
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
    required Map<String, String> items,
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
          
          items: items.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,   
              child: Text(entry.value), 
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
        Uri.parse('https://geopas.satgasprr.go.id/api/excel/wilayah/${level == 4 ? 3 : level}/$parentCode'),
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

    if (_indikatorData.isNotEmpty ) {
      _fetchIndikatorData();
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
                      final now = DateTime.now();
                      if (now.difference(_lastHoverCheck).inMilliseconds < 40) return;
                      _lastHoverCheck = now;

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
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture) {
                        _pruneVisibleMarkers();
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
                    MobileLayerTransformer(
                        child: RepaintBoundary(
                          child: PopupMarkerLayer(
                            options: PopupMarkerLayerOptions(
                              popupController: _popupLayerController,
                              markers: [
                                ..._pekerjaanMarkers,
                                ..._updatedIndikatorMarkers,
                                ..._tkdMarkers,
                              ],
                              popupDisplayOptions: PopupDisplayOptions(
                                snap: PopupSnap.markerTop, 
                                builder: (BuildContext context, Marker marker) {
                                  final dataPayload = (marker.key as ValueKey).value as Map<String, dynamic>;
                                  
                                  if (dataPayload.containsKey('list_sektor_terdampak') || dataPayload.containsKey('indikator')) {
                                    return _buildIndikatorPopup(marker);
                                  } else {
                                    return _buildMarkerPopup(marker);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                    ),
                    MarkerLayer(
                      markers: [
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
                          ..._currentMarkers,
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: RepaintBoundary(
              child: SizedBox(
                width: 150,
                child: 
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSidebarButton(
                      imagePath: 'assets/images/wilayah.png',
                      label: "Wilayah",
                      onTap: () => setState(() {
                        _currentTileUrl = arcgisSatellite;
                        _showMonitorButton = 'wilayah';

                        _indikatorData.clear();
                        _allIndikatorMarkersMasterList.clear();
                        _updatedIndikatorMarkers.clear();

                        _allTkdMarkersMasterList.clear();
                        _tkdMarkers.clear();
                        _tkdData.clear();
                      }),
                    ),
                    const SizedBox(height: 16),
                    _buildSidebarButton(
                      imagePath: 'assets/images/indikator.png',
                      label: "Update kondisi (Indikator)",
                      onTap: () {
                        setState(() {
                          _currentTileUrl = arcgisSatellite;
                          _showMonitorButton = 'update';

                          _allTkdMarkersMasterList.clear();
                          _tkdMarkers.clear();
                          _tkdData.clear();
                        });
                        _fetchIndikatorData();
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildSidebarButton(
                      imagePath: 'assets/images/pekerjaan.png',
                      label: "DalRenduk",
                      onTap: () => setState(() {
                        setState(() {
                          _indikatorData.clear();
                          _allIndikatorMarkersMasterList.clear();
                          _updatedIndikatorMarkers.clear();

                          _allTkdMarkersMasterList.clear();
                          _tkdMarkers.clear();
                          _tkdData.clear();
                        });

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
                      onTap: () => setState(() {
                        _fetchTkdData();

                        _indikatorData.clear();
                        _allIndikatorMarkersMasterList.clear();
                        _updatedIndikatorMarkers.clear();

                        _showMonitorButton = 'tkd';
                        _currentTileUrl = arcgisSatellite;
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),

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
                            thumbColor: WidgetStateProperty.all(Colors.white.withOpacity(0.5)),
                            trackColor: WidgetStateProperty.all(Colors.white10),
                            interactive: true,
                          ),
                        ),
                        child: Scrollbar(
                          controller: _panelScrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          thickness: 6.0,       
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
                    _buildPekerjaanHeader(),
                    
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: _buildPekerjaanList()),
                          
                          Container(width: 1, color: Colors.white10),
                          
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
                  width: 700, 
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1208).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      
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
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                          const SizedBox(height: 20),
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

void parseIndikatorJsonIsolate(Map<String, dynamic> params) {
  final String rawJson = params['jsonString'];
  final SendPort sendPort = params['sendPort'];

  try {
    final Map<String, dynamic> decodedData = json.decode(rawJson);
    final List<dynamic> listIndikator = decodedData['list_indikator'] ?? [];

    List<dynamic> chunkBatch = [];

    for (var indikator in listIndikator) {
      List<dynamic> listSektor = indikator['list_sektor_terdampak'] ?? [];
      for (var sektor in listSektor) {
        
        double? lat = double.tryParse(sektor['latitude']?.toString() ?? '');
        double? lng = double.tryParse(sektor['longitude']?.toString() ?? '');

        if (lat != null && lng != null) {
          chunkBatch.add(sektor);

          if (chunkBatch.length >= 20) {
            sendPort.send(List.from(chunkBatch));
            chunkBatch.clear();
          }
        }
      }
    }

    if (chunkBatch.isNotEmpty) {
      sendPort.send(chunkBatch);
    }
  } catch (e) {
    sendPort.send({'isolate_error': e.toString()});
  } finally {
    sendPort.send('DONE');
  }
}