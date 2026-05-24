import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:http/http.dart' as http;
import 'mapdata/map_data.dart';
import 'package:archive/archive.dart';

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

class AppImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Color? color;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const AppImage(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.color,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (path.contains(':\\') || path.startsWith('\\')) {
      return Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        color: color,
        errorBuilder: errorBuilder,
      );
    }
    
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      color: color,
      errorBuilder: errorBuilder,
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  final MapController _mapController = MapController();
  final ScrollController _panelScrollController = ScrollController();

  final String arcgisSatellite = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  final String arcgisDefault = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';

  late String _currentTileUrl;

  
  List<Marker> _allIndikatorMarkersMasterList = [];
  List<Marker> _allPekerjaanMarkersMasterList = [];

  List<dynamic> _pekerjaanData = [];
  List<Marker> _pekerjaanMarkers = [];

  List<dynamic> _pekerjaanDalrendukData = [];
  List<Marker> _pekerjaanDalrendukMarkers = [];

  List<ClickablePolygon> _activePolygons = [];
  String? _selectedAreaCode;
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
  bool _isShowDalrendukPanel = false;

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

  String? _appDataPath;

  Future<void> _initAppDataPath() async {
    final directory = await getApplicationSupportDirectory();
    setState(() {
      _appDataPath = directory.path;
    });
  }

  List<Map<String, dynamic>> _panelIndikatorData = [];

  Map<String, dynamic>? _selectedProjectData;
  int selectedTab = 0;

  String? _selectedIndikatorCategory; // Tracks the currently chosen category filter

  @override
  void initState() {
    super.initState();
    _currentTileUrl = arcgisSatellite;
    _loadInitialData();
    _initAppDataPath();
  }

  Widget _buildTabContent() {
      switch (selectedTab) {
        case 0:
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _topCard(
                      title: 'Realisasi Keuangan',
                      value: 'Rp. 0',
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _topCard(
                      title: 'Realisasi Fisik',
                      value: '-',
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _topCard(
                      title: 'Realisasi Waktu',
                      value: '-',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                height: 120,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white10,
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grafik Realisasi Timeline',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '-',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

        case 1:
          final Map<String, dynamic> sektor = _selectedProjectData ?? {};

          // Helper widget for specific detail item lines
          Widget buildDetailRow(String label, String value, {bool isStatus = false}) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Text(':', style: TextStyle(color: Colors.white30, fontSize: 13)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: isStatus
                        ? Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                                ),
                                child: Text(
                                  value.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                  ),
                ],
              ),
            );
          }

          // Helper widget for card sections
          Widget buildSectionCard({required IconData icon, required String title, required List<Widget> children}) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF11161D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: const Color(0xFFE2B93B), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: Divider(color: Colors.white10, height: 1),
                  ),
                  ...children,
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT SECTION: DETAIL UTAMA
                Expanded(
                  child: buildSectionCard(
                    icon: Icons.assignment_outlined,
                    title: 'Detail Informasi',
                    children: [
                      Text(
                        'Informasi Paket Pekerjaan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                      buildDetailRow('Tahun Anggaran', sektor['tahun_anggaran'] ?? '-'),
                      buildDetailRow('Nama Paket', sektor['nama'] ?? '-'),
                      buildDetailRow('Program', sektor['nama_program'] ?? '-'),
                      buildDetailRow('Kegiatan / Sub', sektor['nama_kegiatan'] ?? '-'),
                      buildDetailRow('Pagu Dana', sektor['pagu_dana'].toString() ?? '-'),
                      buildDetailRow('Kategori', sektor['kategori_paket_pekerjaan']?['nama'] ?? sektor['indikator']?['nama'] ?? '-'),
                      buildDetailRow('Indikator', sektor['indikator']?['nama'] ?? '-'),
                      buildDetailRow(
                        'Wilayah', 
                        sektor['wilayah']['parent']['parent']['nama']+' '+
                        sektor['wilayah']['parent']['nama']+' '+
                        sektor['wilayah']['nama']
                      ),
                      Text(
                        'Informasi Pengadaan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                      buildDetailRow('Nilai Pagu', sektor['pagu_dana'].toString() ?? '-'),
                      buildDetailRow('Nilai Kontrak', sektor['nilai_kontrak'].toString() ?? '-'),
                      buildDetailRow('Nama Rekening', sektor['nama_rekening'] ?? '-'),
                      buildDetailRow('Penyedia', sektor['penyedia'] ?? '-'),
                      buildDetailRow('No. Kontrak', sektor['no_kontrak'] ?? '-'),
                      buildDetailRow('Masa Pelaksanaan', sektor['no_kontrak'] ?? 's/d'),
                      buildDetailRow('Wilayah', sektor['wilayah']['nama'] ?? 's/d'),
                      buildDetailRow('Koordinat', sektor['latitude']+', '+sektor['longitude'] ?? '-'),
                      buildDetailRow('Keterangan Kondisi', sektor['keterangan_kondisi'] ?? '-'),
                    ],
                  ),
                ),
              ],
            ),
          );

        case 2:
          final Map<String, dynamic> sektor = _selectedProjectData ?? {};

          // Helper widget for specific detail item lines
          Widget buildDetailRow(String label, String value, {bool isStatus = false}) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Text(':', style: TextStyle(color: Colors.white30, fontSize: 13)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: isStatus
                        ? Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                                ),
                                child: Text(
                                  value.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                  ),
                ],
              ),
            );
          }

          // Helper widget for card sections
          Widget buildSectionCard({required IconData icon, required String title, required List<Widget> children}) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF11161D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: const Color(0xFFE2B93B), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: Divider(color: Colors.white10, height: 1),
                  ),
                  ...children,
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT SECTION: DETAIL UTAMA
                Expanded(
                  child: buildSectionCard(
                    icon: Icons.assignment_outlined,
                    title: 'Informasi Penyedia',
                    children: [
                      buildDetailRow('Penyedia', sektor['penyedia'] ?? '-'),
                      buildDetailRow('NIB', '-'),
                      buildDetailRow('NPWP', '-'),
                      buildDetailRow('Nama', '-'),
                      buildDetailRow('Kontak Person', '-'),
                      buildDetailRow('Email', '-'),
                      buildDetailRow('No.Telp', '-'),
                      buildDetailRow('Alamat', '-'),
                    ],
                  ),
                ),
              ],
            ),
          );

        case 3:
          // Proportional layout factors for horizontal columns sizing
          const int flexNo = 1;
          const int flexUser = 3;
          const int flexRole = 3;
          const int flexAktivitas = 6;
          const int flexTanggal = 3;

          // Hardcoded UI Layout design placeholder values
          final List<Map<String, String>> templateData = [];

          return Padding(
            padding: const EdgeInsets.all(4.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF11161D), // Main dark background
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  // ==========================================
                  // STATIC TABLE HEADER HEADER BAND
                  // ==========================================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rincian Paket Pekerjaan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFF161C24), // Darker title banner background
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: flexNo, child: Text('No.', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold))),
                        Expanded(flex: flexUser, child: Text('Nama', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold))),
                        Expanded(flex: flexRole, child: Text('Target', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold))),
                        Expanded(flex: flexAktivitas, child: Text('Satuan', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),

                  // ==========================================
                  // SCROLLABLE BODY DATA ROWS VIEW
                  // ==========================================
                  Expanded(
                    child: ListView.separated(
                      physics: const ClampingScrollPhysics(),
                      itemCount: templateData.length,
                      separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final item = templateData[index];

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          // Alternating subtle zebra striping background
                          color: index % 2 == 0 ? Colors.transparent : Colors.white.withOpacity(0.01),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // NO. Column
                              Expanded(
                                flex: flexNo,
                                child: Text(
                                  item['no']!,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ),
                              // USER Column
                              Expanded(
                                flex: flexUser,
                                child: Text(
                                  item['user']!,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                              // ROLE BADGE CHIP Column
                              Expanded(
                                flex: flexRole,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                    ),
                                    child: Text(
                                      item['role']!,
                                      style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ),
                              ),
                              // ACTIVITY DESCRIPTION Column
                              Expanded(
                                flex: flexAktivitas,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Text(
                                    item['aktivitas']!,
                                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                                  ),
                                ),
                              ),
                              // DATE TIMESTAMP Column
                              Expanded(
                                flex: flexTanggal,
                                child: Text(
                                  item['tanggal']!,
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );

        case 4:
          const int flexNo = 1;
          const int flexUser = 3;
          const int flexRole = 3;
          const int flexAktivitas = 6;
          const int flexTanggal = 3;

          // Hardcoded UI Layout design placeholder values
          final List<Map<String, String>> templateData = [];

          return Padding(
            padding: const EdgeInsets.all(4.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF11161D), // Main dark background
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  // ==========================================
                  // STATIC TABLE HEADER HEADER BAND
                  // ==========================================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rincian Paket Pekerjaan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFF161C24), // Darker title banner background
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: flexNo, child: Text('No.', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold))),
                        Expanded(flex: flexUser, child: Text('Nama', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold))),
                        Expanded(flex: flexRole, child: Text('Tanggal Awal', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold))),
                        Expanded(flex: flexRole, child: Text('Tanggal Akhir', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold))),
                        Expanded(flex: flexRole, child: Text('Target', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),

                  // ==========================================
                  // SCROLLABLE BODY DATA ROWS VIEW
                  // ==========================================
                  Expanded(
                    child: ListView.separated(
                      physics: const ClampingScrollPhysics(),
                      itemCount: templateData.length,
                      separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final item = templateData[index];

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          // Alternating subtle zebra striping background
                          color: index % 2 == 0 ? Colors.transparent : Colors.white.withOpacity(0.01),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // NO. Column
                              Expanded(
                                flex: flexNo,
                                child: Text(
                                  item['no']!,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ),
                              // USER Column
                              Expanded(
                                flex: flexUser,
                                child: Text(
                                  item['user']!,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                              // ROLE BADGE CHIP Column
                              Expanded(
                                flex: flexRole,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                    ),
                                    child: Text(
                                      item['role']!,
                                      style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ),
                              ),
                              // ACTIVITY DESCRIPTION Column
                              Expanded(
                                flex: flexAktivitas,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Text(
                                    item['aktivitas']!,
                                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                                  ),
                                ),
                              ),
                              // DATE TIMESTAMP Column
                              Expanded(
                                flex: flexTanggal,
                                child: Text(
                                  item['tanggal']!,
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );

        case 5:
          const int flexNo = 1;
          const int flexUser = 3;
          const int flexRole = 3;
          const int flexAktivitas = 6;
          const int flexTanggal = 3;

          // Hardcoded UI Layout design placeholder values
          final List<Map<String, String>> templateData = [];

          return Padding(
            padding: const EdgeInsets.all(4.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF11161D), // Main dark background
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  // ==========================================
                  // STATIC TABLE HEADER HEADER BAND
                  // ==========================================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rincian Paket Pekerjaan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFF161C24), // Darker title banner background
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: flexNo, child: Text('No.', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold))),
                        Expanded(flex: flexUser, child: Text('Nama', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold))),
                        Expanded(flex: flexRole, child: Text('Tanggal', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold))),
                        Expanded(flex: flexRole, child: Text('Realisasi', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),

                  // ==========================================
                  // SCROLLABLE BODY DATA ROWS VIEW
                  // ==========================================
                  Expanded(
                    child: ListView.separated(
                      physics: const ClampingScrollPhysics(),
                      itemCount: templateData.length,
                      separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final item = templateData[index];

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          // Alternating subtle zebra striping background
                          color: index % 2 == 0 ? Colors.transparent : Colors.white.withOpacity(0.01),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // NO. Column
                              Expanded(
                                flex: flexNo,
                                child: Text(
                                  item['no']!,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ),
                              // USER Column
                              Expanded(
                                flex: flexUser,
                                child: Text(
                                  item['user']!,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                              // ROLE BADGE CHIP Column
                              Expanded(
                                flex: flexRole,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                    ),
                                    child: Text(
                                      item['role']!,
                                      style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ),
                              ),
                              // ACTIVITY DESCRIPTION Column
                              Expanded(
                                flex: flexAktivitas,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Text(
                                    item['aktivitas']!,
                                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                                  ),
                                ),
                              ),
                              // DATE TIMESTAMP Column
                              Expanded(
                                flex: flexTanggal,
                                child: Text(
                                  item['tanggal']!,
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );

        case 6:
          const int flexNo = 1;
          const int flexUser = 3;
          const int flexRole = 3;
          const int flexAktivitas = 6;
          const int flexTanggal = 3;

          // Hardcoded UI Layout design placeholder values
          final List<Map<String, String>> templateData = [];

          return Padding(
            padding: const EdgeInsets.all(4.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF11161D), // Main dark background
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  // ==========================================
                  // STATIC TABLE HEADER HEADER BAND
                  // ==========================================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rincian Paket Pekerjaan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFF161C24), // Darker title banner background
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: flexNo, child: Text('No.', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold))),
                        Expanded(flex: flexRole, child: Text('Tanggal', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold))),
                        Expanded(flex: flexRole, child: Text('Nominal', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),

                  // ==========================================
                  // SCROLLABLE BODY DATA ROWS VIEW
                  // ==========================================
                  Expanded(
                    child: ListView.separated(
                      physics: const ClampingScrollPhysics(),
                      itemCount: templateData.length,
                      separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final item = templateData[index];

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          // Alternating subtle zebra striping background
                          color: index % 2 == 0 ? Colors.transparent : Colors.white.withOpacity(0.01),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // NO. Column
                              Expanded(
                                flex: flexNo,
                                child: Text(
                                  item['no']!,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ),
                              // USER Column
                              Expanded(
                                flex: flexUser,
                                child: Text(
                                  item['user']!,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                              // ROLE BADGE CHIP Column
                              Expanded(
                                flex: flexRole,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                    ),
                                    child: Text(
                                      item['role']!,
                                      style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ),
                              ),
                              // ACTIVITY DESCRIPTION Column
                              Expanded(
                                flex: flexAktivitas,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Text(
                                    item['aktivitas']!,
                                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                                  ),
                                ),
                              ),
                              // DATE TIMESTAMP Column
                              Expanded(
                                flex: flexTanggal,
                                child: Text(
                                  item['tanggal']!,
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );

        default:
          return const SizedBox();
      }
    }

  Widget _menuItem({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF101A2A)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? const Border(
                  left: BorderSide(
                    color: Color(0xFF3B82F6),
                    width: 3,
                  ),
                )
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected
                ? const Color(0xFF60A5FA)
                : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _topCard({
    required String title,
    required String value,
  }) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _updatePanelIndikatorFromRawJson(String jsonString) {
    try {
      final Map<String, dynamic> data = json.decode(jsonString);
      
      final List<dynamic> listIndikator = data['list_indikator'] ?? [];
      
      final Map<String, Map<String, int>> aggregatedData = {};

      for (var indikator in listIndikator) {
        if (indikator == null || indikator["nama"] == null) continue;
        String categoryName = indikator["nama"].toString();
        
        final List<dynamic> listSektor = indikator["list_sektor_terdampak"] ?? [];

        for (var sektor in listSektor) {
          if (sektor == null) continue;

          final Map<String, dynamic>? wilayah = sektor["wilayah"];
          final String wilayahKode = (wilayah != null && wilayah["kode"] != null) 
              ? wilayah["kode"].toString().trim() 
              : "";

          if (_selectedProvinceId != null && _selectedProvinceId != '0' && _selectedProvinceId!.isNotEmpty) {
            String prefixWithDot = "$_selectedProvinceId.";
            
            if (wilayahKode != _selectedProvinceId && !wilayahKode.startsWith(prefixWithDot)) {
              continue;
            }
          }

          if (!aggregatedData.containsKey(categoryName)) {
            aggregatedData[categoryName] = {
              "total": 0,
              "normal": 0,
              "mendekati": 0,
              "atensi": 0,
            };
          }

          String rawStatus = (sektor["status"] ?? "").toString().trim().toLowerCase();

          aggregatedData[categoryName]!["total"] = aggregatedData[categoryName]!["total"]! + 1;

          if (rawStatus == "normal") {
            aggregatedData[categoryName]!["normal"] = aggregatedData[categoryName]!["normal"]! + 1;
          } else if (rawStatus == "mendekati" || rawStatus == "sedang ditangani") {
            aggregatedData[categoryName]!["mendekati"] = aggregatedData[categoryName]!["mendekati"]! + 1;
          } else if (rawStatus == "atensi" || rawStatus == "belum ditangani") {
            aggregatedData[categoryName]!["atensi"] = aggregatedData[categoryName]!["atensi"]! + 1;
          }
        }
      }

      final List<Map<String, dynamic>> parsedIndicators = [];

      aggregatedData.forEach((categoryName, counts) {
        int total = counts["total"]!;
        int normal = counts["normal"]!;
        
        double pct = total > 0 ? (normal / total) * 100 : 0.0;
        String formattedPercentage = pct == 100.0 ? "100%" : "${pct.toStringAsFixed(2)}%";

        IconData dynamicIcon = Icons.business;
        Color iconColor = const Color(0xFF4DE1B6);

        String lowercaseTitle = categoryName.toLowerCase();
        if (lowercaseTitle.contains("desa") || lowercaseTitle.contains("kelurahan")) {
          dynamicIcon = Icons.domain;
          iconColor = const Color(0xFF5A86E9);
        } else if (lowercaseTitle.contains("lumpur") || lowercaseTitle.contains("bersih")) {
          dynamicIcon = Icons.cleaning_services;
          iconColor = const Color(0xFF3263E3);
        } else if (lowercaseTitle.contains("faskes") || lowercaseTitle.contains("rs") || lowercaseTitle.contains("klinik")) {
          dynamicIcon = Icons.favorite;
          iconColor = lowercaseTitle.contains("klinik") ? const Color(0xFFFABE2C) : const Color(0xFF4279F4);
        } else if (['paud', 'tk', 'sd', 'smp', 'sma', 'sekolah'].any(lowercaseTitle.contains)) {
          dynamicIcon = Icons.school;
          iconColor = lowercaseTitle.contains("paud") ? const Color(0xFF26A69A) : const Color(0xFF3B72E2);
        }

        parsedIndicators.add({
          "title": categoryName,
          "icon": dynamicIcon,
          "color": iconColor,
          "total": total.toString(),
          "normal": normal.toString(),
          "mendekati": counts["mendekati"]!.toString(),
          "atensi": counts["atensi"]!.toString(),
          "percentage": formattedPercentage,
        });
      });

      setState(() {
        _panelIndikatorData.clear();
        _panelIndikatorData.addAll(parsedIndicators);
      });
    } catch (e) {
      debugPrint("Error parsing indicator aggregation view: $e");
    } finally {

    }
  }

  //Widget _buildProgressIndicatorRow(Map<String, dynamic> item) {
  //  return Padding(
  //    padding: const EdgeInsets.symmetric(vertical: 12.0),
  //    child: Column(
  //      crossAxisAlignment: CrossAxisAlignment.start,
  //      children: [
  //        Row(
  //          mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //          crossAxisAlignment: CrossAxisAlignment.start,
  //          children: [
  //            Expanded(
  //              child: Row(
  //                children: [
  //                  Icon(
  //                    item['icon'] as IconData, 
  //                    color: item['color'] as Color, 
  //                    size: 22,
  //                  ),
  //                  const SizedBox(width: 12),
  //                  Expanded(
  //                    child: Text(
  //                      item['title']!,
  //                      style: const TextStyle(
  //                        color: Colors.white,
  //                        fontSize: 13,
  //                        fontWeight: FontWeight.w400,
  //                      ),
  //                    ),
  //                  ),
  //                ],
  //              ),
  //            ),
              
  //            Text(
  //              "Total : ${item['total']} | Normal : ${item['normal']} | Mendekati : ${item['mendekati']} | Atensi : ${item['atensi']}",
  //              style: const TextStyle(
  //                color: Colors.white,
  //                fontSize: 11,
  //                fontWeight: FontWeight.w400,
  //                letterSpacing: 0.2,
  //              ),
  //            ),
  //          ],
  //        ),
  //        const SizedBox(height: 8),
          
  //        Text(
  //          item['percentage']!,
  //          style: const TextStyle(
  //            color: Colors.white,
  //            fontSize: 13,
  //            fontWeight: FontWeight.bold,
  //          ),
  //        ),
  //      ],
  //    ),
  //  );
  //}

  Widget _buildProgressIndicatorRow(Map<String, dynamic> item) {
      // Check if this row is the currently selected active category filter
      final bool isSelected = _selectedIndikatorCategory == item['title'];

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                // If clicked again, clear selection to show all data
                _selectedIndikatorCategory = null;
              } else {
                // Assign the tapped category title to the global state variable
                _selectedIndikatorCategory = item['title'];
              }
            });
            debugPrint(_selectedIndikatorCategory);
            
            // Optional: Call your refresh/re-fetch functions here if needed, e.g.:
             _fetchIndikatorData();
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            // Smooth styling animation feedback when clicked
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? const Color(0xFFD2A86A).withOpacity(0.4) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            item['icon'] as IconData, 
                            color: item['color'] as Color, 
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item['title']!,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFFD2A86A) : Colors.white,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Text(
                      "Total : ${item['total']} | Normal : ${item['normal']} | Mendekati : ${item['mendekati']} | Atensi : ${item['atensi']}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                Text(
                  item['percentage']!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

  String? _getSektorFotoPath(String? fotoFileName) {
    if (fotoFileName == null || fotoFileName.trim().isEmpty) {
      return null;
    }

    if (_appDataPath != null) {
      final String relativePath = 'assets/$fotoFileName';
      final String fullLocalPath = '$_appDataPath/$relativePath'.replaceAll('/', Platform.pathSeparator).replaceAll('\\', Platform.pathSeparator);

      if (File(fullLocalPath).existsSync()) {
        return fullLocalPath;
      }
    }

    return null;
  }

  String _getAssetPath(String relativePath) {
    if (_appDataPath != null) {
      final String combinedPath = '$_appDataPath/$relativePath';
      
      final String fullLocalPath = combinedPath.replaceAll('/', Platform.pathSeparator).replaceAll('\\', Platform.pathSeparator);
      
      if (File(fullLocalPath).existsSync()) {
        return fullLocalPath;
      }
    }
   
    return relativePath;
  }

  String _getCleanFileName(String urlString) {
    final Uri uri = Uri.parse(urlString);
    return uri.pathSegments.last; 
  }

  Future<String> _fetchJsonData(String urlString) async {
    final String fileName = _getCleanFileName(urlString);
    
    try {
      final Directory appDataDir = await getApplicationSupportDirectory();
      final File localCacheFile = File('${appDataDir.path}/json_data/$fileName.json');
      
      if (await localCacheFile.exists()) {
        return await localCacheFile.readAsString();
      }
    } catch (e) {
      debugPrint('[CACHE ERROR]: Failed reading file from AppData: $e');
    }

    final response = await http.get(Uri.parse(urlString));
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Gagal mengambil data dari server API.');
    }
  }

  Future<void> _downloadAllJson() async {
    setState(() => _isLoading = true);
    
    final List<String> endpoints = [
      'https://geopas.satgasprr.go.id/map/get_anggaran',
      'https://geopas.satgasprr.go.id/map/get_indikator',
      'https://geopas.satgasprr.go.id/map/get_pekerjaan',
      'https://geopas.satgasprr.go.id/map/get_wilayah_all',
    ];

    try {
      final Directory appDataDir = await getApplicationSupportDirectory();
      
      for (String url in endpoints) {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          debugPrint(response.body);
          final String fileName = _getCleanFileName(url);
          final File file = File('${appDataDir.path}/json_data/$fileName.json');
          
          await file.parent.create(recursive: true);
          await file.writeAsString(response.body);
        }
      }

      final String zipUrl = 'https://geopas.satgasprr.go.id/download_asset';
      final zipResponse = await http.get(Uri.parse(zipUrl));

      if (zipResponse.statusCode == 200) {
        final Archive archive = ZipDecoder().decodeBytes(zipResponse.bodyBytes);

        for (final ArchiveFile file in archive) {
          final String filename = file.name;
          
          final String localPath = '${appDataDir.path}/$filename';
          final File outFile = File(localPath);

          if (file.isFile) {
            await outFile.parent.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          } else {
            await Directory(localPath).create(recursive: true);
          }
        }
      } else {
        throw Exception('Server returned code ${zipResponse.statusCode} for assets package zip.');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semua data JSON berhasil disinkronisasi ke AppData offline!')),
        );
      }
    } catch (e) {
      debugPrint("Gagal mengunduh cache data JSON ke AppData: $e");
      _showErrorSnippet("Gagal mengunduh data JSON offline.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTkdPopupCard(BuildContext context, Map<String, dynamic> item) {
    final Map<String, dynamic> wilayah = item['wilayah'] ?? {};
    final List<dynamic> alokasiList = item['list_alokasi'] ?? [];

    double totalNominalAlokasi = 0.0;
    for (var alokasi in alokasiList) {
      totalNominalAlokasi += double.tryParse(alokasi['nominal']?.toString() ?? '0') ?? 0.0;
    }

    String formatRupiahCurrency(dynamic val) {
      if (val == null) return "Rp 0";
    
      double numericValue = double.tryParse(val.toString()) ?? 0.0;
      RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      String Function(Match) matchFunc = (Match match) => '${match[1]},';
      return "Rp ${numericValue.toStringAsFixed(0).replaceAllMapped(reg, matchFunc)}";
    }

    return Container(
      width: 300,
      constraints: const BoxConstraints(maxHeight: 380),
      decoration: BoxDecoration(
        color: const Color(0xFA1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF262626),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance, color: Colors.cyanAccent, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                wilayah['nama'] ?? 'Nama Wilayah',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close, color: Colors.white60, size: 16),
                        onPressed: () => _popupLayerController.hideAllPopups(),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 12),
                  _buildTkdPopupRow("Anggaran 2025:", formatRupiahCurrency(item['anggaran_2025'])),
                  const SizedBox(height: 4),
                  _buildTkdPopupRow("Anggaran 2026:", formatRupiahCurrency(item['anggaran_2026'])),
                  const SizedBox(height: 4),
                  _buildTkdPopupRow(
                    "Penyesuaian:", 
                    formatRupiahCurrency(item['penyesuaian']),
                    valueColor: Colors.amberAccent,
                  ),
                ],
              ),
            ),
            
            Container(height: 1, color: Colors.cyanAccent.withOpacity(0.3)),

            const Padding(
              padding: EdgeInsets.only(left: 12, top: 10, bottom: 4),
              child: Text(
                "Rincian Alokasi Urusan:",
                style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
            
            Flexible(
              child: alokasiList.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: Text("Tidak ada rincian data alokasi.", style: TextStyle(color: Colors.white38, fontSize: 11)),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      itemCount: alokasiList.length,
                      separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 8),
                      itemBuilder: (context, index) {
                        final alokasi = alokasiList[index];
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                alokasi['keterangan'] ?? 'Urusan',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatRupiahCurrency(alokasi['nominal']),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        );
                      },
                    ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: const Color(0xFF1E1E1E),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(color: Colors.white30, height: 1, thickness: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total:", 
                        style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        formatRupiahCurrency(totalNominalAlokasi),
                        style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTkdPopupRow(String label, String value, {Color valueColor = Colors.white}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

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
      //final response = await http.get(Uri.parse(url));

      //List<dynamic> data = json.decode(response.body);
      //List<Marker> newMarkers = [];

      final String jsonBody = await _fetchJsonData(url);
      List<dynamic> data = json.decode(jsonBody);
      List<Marker> newMarkers = [];

      for (var item in data) {
        var wilayah = item['wilayah'];
        if (wilayah == null) continue;

        double? lat = double.tryParse(wilayah['latitude']?.toString() ?? '');
        double? lng = double.tryParse(wilayah['longitude']?.toString() ?? '');

        if (lat != null && lng != null) {
          String kondisi = wilayah['kondisi']?.toString() ?? 'Normal';
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
                  child: AppImage(
                    _getAssetPath('assets/icons/$markerImage'),
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
        _pruneVisibleMarkers();
      });
    } catch (e) {
      debugPrint("TKD fetch error: $e");
      _showErrorSnippet("Terjadi kesalahan saat mengambil data Anggaran/TKD.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchIndikatorData() async {
    //if ( (_selectedRegencyId ?? (_selectedProvinceId ?? "")) == '' ) {
    //  _showErrorSnippet("Mohon pilih wilayah terlebih dahulu");
    //  return;
    //}

    setState(() {
      _isLoading = true;
      _indikatorData.clear();
      _allIndikatorMarkersMasterList.clear();
      _updatedIndikatorMarkers.clear();
    });

    String kodeWilayah = _selectedRegencyId ?? (_selectedProvinceId ?? "");
    String url = 'https://geopas.satgasprr.go.id/map/get_indikator?wilayah_kode=$kodeWilayah';

    try {
      //final response = await http.get(Uri.parse(url));

      //final receivePort = ReceivePort();

      //await Isolate.spawn(
      //  parseIndikatorJsonIsolate,
      //  {
      //    'jsonString': response.body,
      //    'sendPort': receivePort.sendPort,
      //  },
      //);

      final String jsonBody = await _fetchJsonData(url);
      _updatePanelIndikatorFromRawJson(jsonBody);

      final receivePort = ReceivePort();

      await Isolate.spawn(
        parseIndikatorJsonIsolate,
        {
          'jsonString': jsonBody,
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
            // =========================================================================
            // NEW FILTER CONDITION: Filter out markers that do not match the selected row
            // =========================================================================
            if (_selectedIndikatorCategory != null && _selectedIndikatorCategory!.isNotEmpty) {
              final String categoryName = (sektor['parent_indikator_nama'] ?? '').toString().trim();

              // Skip generating and showing this marker if it doesn't match the active filter
              if (categoryName != _selectedIndikatorCategory) {
                continue;
              }
            }

            final Map<String, dynamic>? wilayah = sektor['wilayah'];
            final String wilayahKode = (wilayah != null && wilayah['kode'] != null)
                ? wilayah['kode'].toString().trim()
                : "";

            if (_selectedAreaCode != null && _selectedAreaCode!.isNotEmpty) {
              String prefixWithDot = "$_selectedAreaCode.";
              
              if (wilayahKode != _selectedAreaCode && !wilayahKode.startsWith(prefixWithDot)) {
                continue;
              }
            }

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
                    child: AppImage(
                      _getAssetPath('assets/icons/$markerImage'),
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

  //Widget _buildIndikatorPopup(Marker marker) {
  //  final sektor = (marker.key as ValueKey).value as Map<String, dynamic>;

  //  String namaSektor = sektor['nama_lokasi'] ?? 'Tanpa Nama';
  //  String namaIndikator = (sektor['indikator']?['nama'] ?? 'Indikator') + ' Terdampak Bencana';
    
  //  String wilayahInfo = 
  //  [
  //    sektor['wilayah']['parent']['parent']['nama'] ?? '',
  //    sektor['wilayah']['parent']['nama'] ?? '',
  //    sektor['wilayah']['nama'] ?? ''
  //  ].where((element) => element.isNotEmpty).join(' - ');
    
  //  if (wilayahInfo.isEmpty) {
  //    wilayahInfo = sektor['wilayah']?['nama'] ?? '-';
  //  }

  //  String kondisi = sektor['kondisi'] ?? '-';
  //  String status = sektor['status'] ?? '-';
  //  String kondisiAwal = sektor['kondisi_awal'] ?? '-';
  //  String keterangan = sektor['keterangan'] ?? '-';

  //  double persentasePulih = 0.0;
  //  var rawPersentase = sektor['persentase'];
  //  if (rawPersentase != null) {
  //    persentasePulih = double.tryParse(rawPersentase.toString()) ?? 0.0;
  //  }

  //  String markerImage = '';
  //  if (sektor['indikator']['nama'].contains('Kantor')) {
  //      markerImage = 'building';
  //  } else if (sektor['indikator']['nama'].contains('Faskes')) {
  //      markerImage = 'health';
  //  } else if (
  //      sektor['indikator']['nama'].contains('PAUD') ||
  //      sektor['indikator']['nama'].contains('TK') ||
  //      sektor['indikator']['nama'].contains('SD') ||
  //      sektor['indikator']['nama'].contains('SMP') ||
  //      sektor['indikator']['nama'].contains('SMA/SMK') ||
  //      sektor['indikator']['nama'].contains('Madrasah/Ponpes')
  //    ) {
  //      markerImage = 'school';
  //  } else if (sektor['indikator']['nama'].contains('Jalan')) {
  //      markerImage = 'road';
  //  } else if (sektor['indikator']['nama'].contains('Jembatan')) {
  //      markerImage = 'bride';
  //  } else if (sektor['indikator']['nama'].contains('Kelistrikan')) {
  //      markerImage = 'electric';
  //  } else if (sektor['indikator']['nama'].contains('PDAM/SPAM')) {
  //      markerImage = 'water';
  //  } else if (sektor['indikator']['nama'].contains('Gedung Rumah Ibadah')) {
  //      markerImage = 'religion';
  //  } else if (sektor['indikator']['nama'].contains('Sungai')) {
  //      markerImage = 'river';
  //  } else if (
  //      sektor['indikator']['nama'].contains('Huntara') ||
  //      sektor['indikator']['nama'].contains('Huntap')
  //    ) {
  //      markerImage = 'home';
  //  } else if (sektor['indikator']['nama'].contains('Pengungsian')) {
  //      markerImage = 'homes';
  //  } else if (
  //      sektor['indikator']['nama'].contains('toko diluar pasar') ||
  //      sektor['indikator']['nama'].contains('Hotel/Penginapan')
  //    ) {
  //      markerImage = 'building';
  //  } else if (sektor['indikator']['nama'].contains('SPBU')) {
  //      markerImage = 'gas_station';
  //  } else if (sektor['indikator']['nama'].contains('Gas LPG')) {
  //      markerImage = 'gas';
  //  } else if (
  //      sektor['indikator']['nama'].contains('Gedung/Sarpras Pasar') ||
  //      sektor['indikator']['nama'].contains('Gedung/Sarpras Resto/Warung/Kafe/kedai') ||
  //      sektor['indikator']['nama'].contains('Koperasi')
  //    ) {
  //      markerImage = 'store';
  //  } else if (sektor['indikator']['nama'].contains('INTERNET')) {
  //      markerImage = 'help';
  //  } else if (
  //      sektor['indikator']['nama'].contains('Persawahan') ||
  //      sektor['indikator']['nama'].contains('Perikanan (Tambak)')
  //    ) {
  //      markerImage = 'river';
  //  } else if (
  //      sektor['indikator']['nama'].contains('Pembersihan lumpur') ||
  //      sektor['indikator']['nama'].contains('DTH')
  //    ) {
  //      markerImage = 'help';
  //  }

  //  switch (sektor['status']) {
  //    case 'Atensi':
  //      markerImage += '-yellow';
  //    break;
  //    case 'Mendekati':
  //      markerImage += '-blue';
  //    break;
  //    case 'Sedang ditangani':
  //      markerImage += '-blue';
  //    break;
  //    case 'Belum ditangani':
  //      markerImage += '-red';
  //    break;
  //    default:
  //  }
  //  markerImage += '.png';

  //  final String? sebelumPath = _getSektorFotoPath(sektor['foto_sebelum']);
  //  final String? sesudahPath = _getSektorFotoPath(sektor['foto_sesudah']);

  //  void _showLargeImageView(String title, String imagePath) {
  //    showDialog(
  //      context: context,
  //      builder: (BuildContext context) {
  //        bool isExpanded = false;

  //        return StatefulBuilder(
  //          builder: (context, setDialogState) {
  //            return Dialog(
  //              backgroundColor: Colors.transparent,
  //              insetPadding: const EdgeInsets.all(16), 
  //              child: Stack(
  //                alignment: Alignment.center,
  //                children: [
  //                  GestureDetector(
  //                    onTap: () => Navigator.of(context).pop(),
  //                    child: Container(color: Colors.transparent),
  //                  ),
                    
  //                  AnimatedContainer(
  //                    duration: const Duration(milliseconds: 300),
  //                    curve: Curves.easeInOut,
  //                    width: isExpanded ? MediaQuery.of(context).size.width * 0.95 : 800, 
  //                    height: isExpanded ? MediaQuery.of(context).size.height * 0.90 : 600,
  //                    decoration: BoxDecoration(
  //                      color: const Color(0xFF1a2c42),
  //                      borderRadius: BorderRadius.circular(12),
  //                      border: Border.all(color: Colors.white12),
  //                    ),
  //                    child: Column(
  //                      mainAxisSize: MainAxisSize.min,
  //                      children: [
  //                        Padding(
  //                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //                          child: Row(
  //                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                            children: [
  //                              Expanded(
  //                                child: Text(
  //                                  title,
  //                                  overflow: TextOverflow.ellipsis,
  //                                  style: const TextStyle(
  //                                    color: Colors.white, 
  //                                    fontSize: 14, 
  //                                    fontWeight: FontWeight.bold,
  //                                  ),
  //                                ),
  //                              ),
  //                              Text(
  //                                isExpanded ? "Klik foto untuk mengecilkan" : "Klik foto untuk memperbesar",
  //                                style: const TextStyle(color: Colors.white38, fontSize: 11),
  //                              ),
  //                              const SizedBox(width: 8),
  //                              IconButton(
  //                                icon: const Icon(Icons.close, color: Colors.white60, size: 20),
  //                                onPressed: () => Navigator.of(context).pop(),
  //                              ),
  //                            ],
  //                          ),
  //                        ),
  //                        const Divider(color: Colors.white12, height: 1),
                          
  //                        Flexible(
  //                          child: Padding(
  //                            padding: const EdgeInsets.all(16),
  //                            child: GestureDetector(
  //                              onTap: () {
  //                                setDialogState(() {
  //                                  isExpanded = !isExpanded;
  //                                });
  //                              },
  //                              child: MouseRegion(
  //                                cursor: SystemMouseCursors.click,
  //                                child: ClipRRect(
  //                                  borderRadius: BorderRadius.circular(8),
  //                                  child: AnimatedSize(
  //                                    duration: const Duration(milliseconds: 300),
  //                                    curve: Curves.easeInOut,
  //                                    child: AppImage(
  //                                      imagePath,
  //                                      fit: isExpanded ? BoxFit.contain : BoxFit.cover,
  //                                      width: double.infinity,
  //                                      height: double.infinity,
  //                                    ),
  //                                  ),
  //                                ),
  //                              ),
  //                            ),
  //                          ),
  //                        ),
  //                      ],
  //                    ),
  //                  ),
  //                ],
  //              ),
  //            );
  //          },
  //        );
  //      },
  //    );
  //  }

  //  return Container(
  //    width: 320,
  //    padding: const EdgeInsets.all(16),
  //    decoration: BoxDecoration(
  //      color: const Color(0xFF1A1A1A),
  //      borderRadius: BorderRadius.circular(12),
  //      boxShadow: const [
  //        BoxShadow(blurRadius: 12, color: Colors.black, offset: Offset(0, 4))
  //      ],
  //    ),
  //    child: Stack(
  //      children: [
  //        Padding(
  //          padding: const EdgeInsets.all(16),
  //          child: Column(
  //            mainAxisSize: MainAxisSize.min,
  //            crossAxisAlignment: CrossAxisAlignment.start,
  //            children: [
  //              Text(
  //                namaSektor.toUpperCase(),
  //                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
  //              ),
  //              const SizedBox(height: 12),
  //              const Divider(color: Colors.white24, height: 1),
  //              const SizedBox(height: 12),

  //              Row(
  //                mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                children: [
  //                  const Text("Persentase Pulih:", style: TextStyle(color: Colors.white70, fontSize: 12)),
  //                  Text(
  //                    "${persentasePulih.toStringAsFixed(0)}%",
  //                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
  //                  ),
  //                ],
  //              ),
  //              const SizedBox(height: 8),
  //              ClipRRect(
  //                borderRadius: BorderRadius.circular(4),
  //                child: LinearProgressIndicator(
  //                  value: persentasePulih / 100,
  //                  backgroundColor: Colors.white10,
  //                  color: const Color(0xFF4CAF50),
  //                  minHeight: 8,
  //                ),
  //              ),
  //              const SizedBox(height: 16),

  //              Container(
  //                padding: const EdgeInsets.all(12),
  //                decoration: BoxDecoration(
  //                  color: Colors.white.withOpacity(0.04),
  //                  borderRadius: BorderRadius.circular(8),
  //                ),
  //                child: Row(
  //                  children: [
  //                    AppImage(
  //                      _getAssetPath('assets/icons/$markerImage'),
  //                      width: 20,
  //                      height: 20,
  //                      fit: BoxFit.contain,
  //                      errorBuilder: (context, error, stackTrace) {
  //                        return const Icon(Icons.assignment, color: Colors.tealAccent, size: 20);
  //                      },
  //                    ),
  //                    const SizedBox(width: 12),
  //                    Expanded(
  //                      child: Text(
  //                        namaIndikator,
  //                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
  //                      ),
  //                    ),
  //                  ],
  //                ),
  //              ),
  //              const SizedBox(height: 12),

  //              Container(
  //                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
  //                decoration: BoxDecoration(
  //                  color: Colors.white.withOpacity(0.04),
  //                  borderRadius: BorderRadius.circular(8),
  //                ),
  //                child: Row(
  //                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //                  children: [
  //                    Expanded(
  //                      child: Center(
  //                        child: sebelumPath != null
  //                            ? InkWell(
  //                              borderRadius: BorderRadius.circular(4),
  //                              onTap: () => _showLargeImageView("Foto Kondisi Sebelum", sebelumPath),
  //                              child: Tooltip(
  //                                message: "Klik untuk memperbesar",
  //                                child: 
  //                                ClipRRect(
  //                                  borderRadius: BorderRadius.circular(4),
  //                                  child: AppImage(
  //                                    sebelumPath,
  //                                    width: 100,
  //                                    height: 70,
  //                                    fit: BoxFit.cover,
  //                                    errorBuilder: (context, error, stackTrace) => const Text(
  //                                      "Gagal Memuat Gambar", 
  //                                      style: TextStyle(color: Colors.redAccent, fontSize: 11)
  //                                    ),
  //                                  ),
  //                                ),
  //                              ),
  //                            )
  //                          : const Text("Belum Dilaporkan", style: TextStyle(color: Colors.white38, fontSize: 12)),
  //                      ),
  //                    ),
  //                    Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.2), size: 16),
  //                    Expanded(
  //                      child: Center(
  //                        child: sesudahPath != null
  //                            ? InkWell(
  //                                borderRadius: BorderRadius.circular(4),
  //                                onTap: () => _showLargeImageView("Foto Kondisi Sesudah", sesudahPath),
  //                                child: Tooltip(
  //                                  message: "Klik untuk memperbesar",
  //                                  child: ClipRRect(
  //                                    borderRadius: BorderRadius.circular(4),
  //                                    child: AppImage(
  //                                      sesudahPath,
  //                                      width: 100,
  //                                      height: 70,
  //                                      fit: BoxFit.cover,
  //                                      errorBuilder: (context, error, stackTrace) => const Text(
  //                                        "Gagal Memuat Gambar", 
  //                                        style: TextStyle(color: Colors.redAccent, fontSize: 11)
  //                                      ),
  //                                    ),
  //                                  ),
  //                                ),
  //                              )
  //                            : const Text("Belum Dilaporkan", style: TextStyle(color: Colors.white38, fontSize: 12)),
  //                      ),
  //                    ),
  //                  ],
  //                ),
  //              ),
  //              const SizedBox(height: 16),

  //              _buildMetaRow("Wilayah", wilayahInfo),
  //              _buildMetaRow("Kondisi", kondisi),
  //              _buildMetaRow("Status", status),
  //              _buildMetaRow("Kondisi Awal", kondisiAwal),
  //              _buildMetaRow("Keterangan", keterangan),
  //            ],
  //          ),
  //        ),
  //        Positioned(
  //          top: 4, 
  //          right: 4,
  //          child: IconButton(
  //            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
  //            tooltip: 'Tutup',
  //            onPressed: () {
  //              _popupLayerController.hideAllPopups();
  //            },
  //          ),
  //        ),
  //      ],
  //    ),
  //  );
  //}

  Widget _buildIndikatorPopup(Marker marker) {
      // Safely cast the raw project Map payload straight out from the active marker key
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

      final String? sebelumPath = _getSektorFotoPath(sektor['foto_sebelum']);
      final String? sesudahPath = _getSektorFotoPath(sektor['foto_sesudah']);

      void _showLargeImageView(String title, String imagePath) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            bool isExpanded = false;

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(16), 
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(color: Colors.transparent),
                      ),
                      
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: isExpanded ? MediaQuery.of(context).size.width * 0.95 : 800, 
                        height: isExpanded ? MediaQuery.of(context).size.height * 0.90 : 600,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1a2c42),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white, 
                                        fontSize: 14, 
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    isExpanded ? "Klik foto untuk mengecilkan" : "Klik foto untuk memperbesar",
                                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(color: Colors.white12, height: 1),
                            
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      isExpanded = !isExpanded;
                                    });
                                  },
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: AnimatedSize(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                        child: AppImage(
                                          imagePath,
                                          fit: isExpanded ? BoxFit.contain : BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      }
      
      //String wilayahInfo = [
      //  sektor['wilayah']?['parent']?['parent']?['nama'] ?? '',
      //  sektor['wilayah']?['parent']?['nama'] ?? '',
      //  sektor['wilayah']?['nama'] ?? ''
      //].where((element) => element.isNotEmpty).join(' - ');

      return Container(
        width: 300,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFA1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        //child: Column(
        //  mainAxisSize: MainAxisSize.min,
        //  crossAxisAlignment: CrossAxisAlignment.start,
        //  children: [
        //    Row(
        //      mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //      children: [
        //        Expanded(
        //          child: Text(
        //            namaSektor,
        //            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        //            maxLines: 1,
        //            overflow: TextOverflow.ellipsis,
        //          ),
        //        ),
        //        IconButton(
        //          constraints: const BoxConstraints(),
        //          padding: EdgeInsets.zero,
        //          icon: const Icon(Icons.close, color: Colors.white60, size: 16),
        //          onPressed: () => _popupLayerController.hideAllPopups(),
        //        ),
        //      ],
        //    ),
        //    const Divider(color: Colors.white24, height: 12),
            
        //    Text(
        //      "Indikator: $namaIndikator",
        //      style: const TextStyle(color: Colors.white70, fontSize: 11),
        //    ),
        //    const SizedBox(height: 4),
        //    Text(
        //      "Wilayah: $wilayahInfo",
        //      style: const TextStyle(color: Colors.white60, fontSize: 11),
        //      maxLines: 2,
        //      overflow: TextOverflow.ellipsis,
        //    ),
            
        //    const SizedBox(height: 12),
        //    Row(
        //      children: [
        //        Expanded(
        //          child: GestureDetector(
        //            onTap: () {
        //              setState(() {
        //                // 1. Dismiss the indicator popup overlay box
        //                _popupLayerController.hideAllPopups();
                        
        //                // 2. Safeguard that data is mapped onto your main tracking holder
        //                _selectedProjectData = sektor;
                        
        //                // 3. Open the main panel container layout widget context
        //                _isShowDalrendukPanel = true;
                        
        //                // 4. Match tab view index selection to focus 'Informasi' (Case 1)
        //                selectedTab = 1; 
        //              });
        //            },
        //            child: Container(
        //              padding: const EdgeInsets.symmetric(vertical: 8),
        //              decoration: BoxDecoration(
        //                color: const Color(0xFF22467A),
        //                borderRadius: BorderRadius.circular(6),
        //              ),
        //              child: const Center(
        //                child: Text(
        //                  "Detail", 
        //                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        //                ),
        //              ),
        //            ),
        //          ),
        //        ),
        //      ],
        //    )
        //  ],
        //),
        child:Stack(
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
                        AppImage(
                          _getAssetPath('assets/icons/$markerImage'),
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
                        Expanded(
                          child: Center(
                            child: sebelumPath != null
                                ? InkWell(
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: () => _showLargeImageView("Foto Kondisi Sebelum", sebelumPath),
                                  child: Tooltip(
                                    message: "Klik untuk memperbesar",
                                    child: 
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: AppImage(
                                        sebelumPath,
                                        width: 100,
                                        height: 70,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Text(
                                          "Gagal Memuat Gambar", 
                                          style: TextStyle(color: Colors.redAccent, fontSize: 11)
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : const Text("Belum Dilaporkan", style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.2), size: 16),
                        Expanded(
                          child: Center(
                            child: sesudahPath != null
                                ? InkWell(
                                    borderRadius: BorderRadius.circular(4),
                                    onTap: () => _showLargeImageView("Foto Kondisi Sesudah", sesudahPath),
                                    child: Tooltip(
                                      message: "Klik untuk memperbesar",
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: AppImage(
                                          sesudahPath,
                                          width: 100,
                                          height: 70,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => const Text(
                                            "Gagal Memuat Gambar", 
                                            style: TextStyle(color: Colors.redAccent, fontSize: 11)
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : const Text("Belum Dilaporkan", style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ),
                        ),
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

  //Widget _buildDalrendukPopup(Marker marker) {
  //  final sektor = (marker.key as ValueKey).value as Map<String, dynamic>;

  //  String namaWilayah = 
  //    sektor['wilayah']['parent']['parent']['nama'] + ' - ' +sektor['wilayah']['parent']['nama'] + ' - ' + sektor['wilayah']['nama']
  //  ;
  //  String namaSektor = sektor['nama'] ?? '-';
  //  String formatRupiah(dynamic rawValue) {
  //    if (rawValue == null) return 'Rp. 0';
      
  //    String digitsOnly = rawValue.toString().replaceAll(RegExp(r'[^0-9]'), '');
  //    if (digitsOnly.isEmpty) return 'Rp. 0';
      
  //    final intValue = int.tryParse(digitsOnly) ?? 0;
      
  //    final RegExp regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  //    String formatted = intValue.toString().replaceAllMapped(regex, (Match m) => '${m[1]}.');
      
  //    return 'Rp. $formatted';
  //  }

  //  String nominal = formatRupiah(sektor['nominal']);

  //  String markerImage = '';
  //  if (sektor['indikator']['nama'].contains('Kantor')) {
  //      markerImage = 'building';
  //  } else if (sektor['indikator']['nama'].contains('Faskes')) {
  //      markerImage = 'health';
  //  } else if (
  //      sektor['indikator']['nama'].contains('PAUD') ||
  //      sektor['indikator']['nama'].contains('TK') ||
  //      sektor['indikator']['nama'].contains('SD') ||
  //      sektor['indikator']['nama'].contains('SMP') ||
  //      sektor['indikator']['nama'].contains('SMA/SMK') ||
  //      sektor['indikator']['nama'].contains('Madrasah/Ponpes')
  //    ) {
  //      markerImage = 'school';
  //  } else if (sektor['indikator']['nama'].contains('Jalan')) {
  //      markerImage = 'road';
  //  } else if (sektor['indikator']['nama'].contains('Jembatan')) {
  //      markerImage = 'bride';
  //  } else if (sektor['indikator']['nama'].contains('Kelistrikan')) {
  //      markerImage = 'electric';
  //  } else if (sektor['indikator']['nama'].contains('PDAM/SPAM')) {
  //      markerImage = 'water';
  //  } else if (sektor['indikator']['nama'].contains('Gedung Rumah Ibadah')) {
  //      markerImage = 'religion';
  //  } else if (sektor['indikator']['nama'].contains('Sungai')) {
  //      markerImage = 'river';
  //  } else if (
  //      sektor['indikator']['nama'].contains('Huntara') ||
  //      sektor['indikator']['nama'].contains('Huntap')
  //    ) {
  //      markerImage = 'home';
  //  } else if (sektor['indikator']['nama'].contains('Pengungsian')) {
  //      markerImage = 'homes';
  //  } else if (
  //      sektor['indikator']['nama'].contains('toko diluar pasar') ||
  //      sektor['indikator']['nama'].contains('Hotel/Penginapan')
  //    ) {
  //      markerImage = 'building';
  //  } else if (sektor['indikator']['nama'].contains('SPBU')) {
  //      markerImage = 'gas_station';
  //  } else if (sektor['indikator']['nama'].contains('Gas LPG')) {
  //      markerImage = 'gas';
  //  } else if (
  //      sektor['indikator']['nama'].contains('Gedung/Sarpras Pasar') ||
  //      sektor['indikator']['nama'].contains('Gedung/Sarpras Resto/Warung/Kafe/kedai') ||
  //      sektor['indikator']['nama'].contains('Koperasi')
  //    ) {
  //      markerImage = 'store';
  //  } else if (sektor['indikator']['nama'].contains('INTERNET')) {
  //      markerImage = 'help';
  //  } else if (
  //      sektor['indikator']['nama'].contains('Persawahan') ||
  //      sektor['indikator']['nama'].contains('Perikanan (Tambak)')
  //    ) {
  //      markerImage = 'river';
  //  } else if (
  //      sektor['indikator']['nama'].contains('Pembersihan lumpur') ||
  //      sektor['indikator']['nama'].contains('DTH')
  //    ) {
  //      markerImage = 'help';
  //  }
  //  markerImage += '.png';

  //  return Container(
  //    width: 320,
  //    padding: const EdgeInsets.all(16),
  //    decoration: BoxDecoration(
  //      color: const Color(0xFF1A1A1A),
  //      borderRadius: BorderRadius.circular(12),
  //      boxShadow: const [
  //        BoxShadow(blurRadius: 12, color: Colors.black, offset: Offset(0, 4))
  //      ],
  //    ),
  //    child: Stack(
  //      children: [
  //        Padding(
  //          padding: const EdgeInsets.all(16),
  //          child: Column(
  //            mainAxisSize: MainAxisSize.min,
  //            crossAxisAlignment: CrossAxisAlignment.start,
  //            children: [
  //              Row(
  //                children: [
  //                  AppImage(
  //                    _getAssetPath('assets/icons/$markerImage'),
  //                    width: 20,
  //                    height: 20,
  //                    fit: BoxFit.contain,
  //                    errorBuilder: (context, error, stackTrace) {
  //                      return const Icon(Icons.assignment, color: Colors.tealAccent, size: 20);
  //                    },
  //                  ),
  //                  const SizedBox(width: 12),
  //                  Expanded(
  //                    child: Text(
  //                      namaWilayah,
  //                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
  //                    ),
  //                  ),
  //                ],
  //              ),
  //              const SizedBox(height: 12),
  //              const Divider(color: Colors.white24, height: 1),
  //              const SizedBox(height: 12),
  //              Container(
  //                child: Text(
  //                  namaSektor,
  //                  style: const TextStyle(color: Color(0xFF90B6D9), fontSize: 14, fontWeight: FontWeight.w500),
  //                ),
  //              ),
  //              const SizedBox(height: 12),
  //              const Divider(color: Colors.white24, height: 1),
  //              const SizedBox(height: 12),
  //              Container(
  //                child: Row(
  //                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                  children: [
  //                    const Text(
  //                      'Nominal Pekerjaan:',
  //                      style: TextStyle(
  //                        color: Colors.white,
  //                        fontSize: 12,
  //                        fontWeight: FontWeight.w500,
  //                      ),
  //                    ),
  //                    Text(
  //                      nominal,
  //                      style: const TextStyle(
  //                        color: Colors.white,
  //                        fontSize: 12,
  //                        fontWeight: FontWeight.w700,
  //                      ),
  //                    ),
  //                  ],
  //                ),
  //              )
  //            ],
  //          ),
  //        ),
  //        Positioned(
  //          top: 4, 
  //          right: 4,
  //          child: IconButton(
  //            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
  //            tooltip: 'Tutup',
  //            onPressed: () {
  //              _popupLayerController.hideAllPopups();
  //            },
  //          ),
  //        ),
  //      ],
  //    ),
  //  );
  //}

  Widget _buildDalrendukPopup(Marker marker) {
    final sektor = (marker.key as ValueKey).value as Map<String, dynamic>;

    // Safely extract names down the hierarchy tree
    String provinsi = sektor['wilayah']?['parent']?['parent']?['nama'] ?? '-';
    String kabupaten = sektor['wilayah']?['parent']?['nama'] ?? '-';
    String kecamatan = sektor['wilayah']?['nama'] ?? '-';
    
    String namaSektor = sektor['nama'] ?? '-';
    
    String formatRupiah(dynamic rawValue) {
      if (rawValue == null) return 'Rp. 0';
      String digitsOnly = rawValue.toString().replaceAll(RegExp(r'[^0-9]'), '');
      if (digitsOnly.isEmpty) return 'Rp. 0';
      final intValue = int.tryParse(digitsOnly) ?? 0;
      final RegExp regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      String formatted = intValue.toString().replaceAllMapped(regex, (Match m) => '${m[1]}.');
      return 'Rp. $formatted';
    }

    String nominal = formatRupiah(sektor['nominal']);

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
    markerImage += '.png';

    // Helper builder for metadata items
    Widget buildMetaRow(String label, String value, {Color? valueColor}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
              ),
            ),
            const Text(':', style: TextStyle(color: Colors.white30, fontSize: 11)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.white.withOpacity(0.85),
                  fontSize: 11,
                  fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Helper builder for bottom action button row
    //Widget buildActionButton(String label, IconData icon, VoidCallback onTap) {
    //  return Expanded(
    //    child: Padding(
    //      padding: const EdgeInsets.symmetric(horizontal: 2.0),
    //      child: OutlinedButton.icon(
    //        onPressed: onTap,
    //        icon: Icon(icon, size: 12, color: Colors.white70),
    //        label: Text(
    //          label,
    //          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
    //        ),
    //        style: OutlinedButton.styleFrom(
    //          padding: const EdgeInsets.symmetric(vertical: 10),
    //          side: const BorderSide(color: Colors.white12),
    //          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    //          backgroundColor: Colors.white.withOpacity(0.02),
    //        ),
    //      ),
    //    ),
    //  );
    //}

    Widget buildActionButton(String label, IconData icon, VoidCallback onTap, {bool isActive = false}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3.0), // Balanced side padding
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(
              icon, 
              size: 13, 
              color: isActive ? Colors.white : Colors.white.withOpacity(0.9),
            ),
            label: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white.withOpacity(0.9), 
                fontSize: 11, 
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              // Dynamically set background color matching the image reference
              backgroundColor: isActive ? const Color(0xFF0F172A) : const Color(0xFF334155),
              // Clean up borders depending on state
              side: BorderSide(
                color: isActive ? Colors.white10 : Colors.transparent, 
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Navy-slate background color frame matching screenshot
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(blurRadius: 16, color: Colors.black.withOpacity(0.6), offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Panel Row Zone
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: Row(
              children: [
                AppImage(
                  _getAssetPath('assets/icons/$markerImage'),
                  width: 18,
                  height: 18,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.assignment, color: Colors.tealAccent, size: 18);
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    namaSektor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                  onPressed: () => _popupLayerController.hideAllPopups(),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // 2. Metadata Content Details Zone
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildMetaRow("Provinsi", provinsi),
                buildMetaRow("Kabupaten", kabupaten),
                buildMetaRow("Kecamatan", kecamatan),
                buildMetaRow("Nominal Pekerjaan", nominal, valueColor: const Color(0xFF60A5FA)), // Accent light blue nominal text
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // 3. Three Bottom Action Buttons Row
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                buildActionButton("Detail", Icons.info_outline, () {
                  // TODO: Wire up your specific custom detail callback action
                  setState(() {
                    _isShowDalrendukPanel = true;                    
                  });
                }),
                buildActionButton("Dokumentasi", Icons.camera_alt_outlined, () {
                  // TODO: Wire up your image stack dialog viewer action
                }),
                buildActionButton("Progres", Icons.trending_up, () {
                  // TODO: Wire up your chart timeline view list logic action
                }),
              ],
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
      itemCount: _pekerjaanDalrendukData.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final header = _pekerjaanDalrendukData[index];
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
    if (_pekerjaanDalrendukData.isEmpty) return const SizedBox();

    final selectedHeader = _pekerjaanDalrendukData[_selectedPekerjaanIndex];
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

  Future<void> _fetchPekerjaanSummary(String kode) async {
    setState(() => _isLoading = true);

    try {
      //final response = await http.get(
      //  Uri.parse('https://geopas.satgasprr.go.id/map/get_pekerjaan?wilayah_kode=$kode'),
      //);

      //List<dynamic> data = json.decode(response.body);
      //List<Marker> newMarkers = [];

      final String url = 'https://geopas.satgasprr.go.id/map/get_pekerjaan?wilayah_kode=$kode';
      final String jsonBody = await _fetchJsonData(url);
      
      List<dynamic> data = json.decode(jsonBody);
      List<Marker> newMarkers = [];

      for (var agency in data) {
        List<dynamic> projects = agency['list_pekerjaan'] ?? [];
        
        for (var project in projects) {
          final Map<String, dynamic>? wilayah = project['wilayah'];
          final String wilayahKode = (wilayah != null && wilayah['kode'] != null)
              ? wilayah['kode'].toString().trim()
              : "";

          if (_selectedAreaCode != null && _selectedAreaCode!.isNotEmpty) {
            String prefixWithDot = "$_selectedAreaCode.";
            
            if (wilayahKode != _selectedAreaCode && !wilayahKode.startsWith(prefixWithDot)) {
              continue;
            }
          }

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

            //newMarkers.add(
            //  Marker(
            //    point: LatLng(lat, lng),
            //    width: 40,
            //    height: 40,
            //    key: ValueKey(project), 
            //    child: AppImage(
            //      _getAssetPath('assets/icons/$markerImage'),
            //      fit: BoxFit.contain,
            //    ),
            //  ),
            //);
            //newMarkers.add(
            //  Marker(
            //    point: LatLng(lat, lng),
            //    width: 40,
            //    height: 40,
            //    key: ValueKey(project), 
            //    child: GestureDetector(
            //      behavior: HitTestBehavior.opaque,
            //      onTap: () {
            //        setState(() {
            //          // 1. Save the exact project clicked to our tracker variable
            //          _selectedProjectData = project;
                      
            //          // 2. Open up your actual bottom panel sheet
            //          _isShowDalrendukPanel = true;
                      
            //          // 3. Switch the content view directly over to your information tab (Case 1)
            //          selectedTab = 1; 
            //        });
            //      },
            //      child: AppImage(
            //        _getAssetPath('assets/icons/$markerImage'),
            //        fit: BoxFit.contain,
            //      ),
            //    ),
            //  ),
            //);
            // 1. Declare the unique marker variable first so it can be passed into its own onTap method safely.
            // Declare the single marker variable to reference it in its own tap closure cleanly
            late final Marker uniqueMarker;
            
            uniqueMarker = Marker(
              point: LatLng(lat, lng),
              width: 40,
              height: 40,
              key: ValueKey(project), 
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    // Cache the clicked map entry directly into your state data pointer
                    _selectedProjectData = project;
                  });
                  // Show the overlay window widget anchor over this active point
                  _popupLayerController.togglePopup(uniqueMarker);
                },
                child: AppImage(
                  _getAssetPath('assets/icons/$markerImage'),
                  fit: BoxFit.contain,
                ),
              ),
            );

            newMarkers.add(uniqueMarker);
          }
        }
      }

      setState(() {
        _pekerjaanDalrendukData = List<Map<String, dynamic>>.from(data);
        _pekerjaanDalrendukMarkers = newMarkers; 
        _selectedPekerjaanIndex = 0;
      });
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

      // 1. Define Local Cache File Path
      final Directory appDataDir = await getApplicationSupportDirectory();
      final File localCacheFile = File('${appDataDir.path}/json_data/get_wilayah_all.json');

      List<dynamic> areas = [];
      bool isLoadedFromCache = false;

      // 2. Try loading and filtering from Local Cache
      if (await localCacheFile.exists()) {
        try {
          final String jsonString = await localCacheFile.readAsString();
          final List<dynamic> allCachedData = json.decode(jsonString);

          // Filter the flat list matching the parent_kode context logic
          if (_currentLevel == 1) {
            areas = allCachedData.where((area) => area['parent_kode'] == null).toList();
          } else {
            areas = allCachedData.where((area) {;
              return area['parent_kode']?.toString().trim() == parentCode.trim();
            }).toList();
          }

          isLoadedFromCache = true;
          debugPrint("Panel read ${areas.length} areas from local JSON cache.");
        } catch (cacheError) {
          debugPrint("Panel cache error, falling back to API: $cacheError");
        }
      }

      // 3. Fallback: Hit the Remote API Endpoint if Cache doesn't exist/failed
      if (!isLoadedFromCache) {
        debugPrint("Panel cache not found or failed. Directing to remote API call...");
        String auth = 'Basic ${base64Encode(utf8.encode('aingExcel:machinegunkelly'))}';
        
        final response = await http.get(
          Uri.parse('https://geopas.satgasprr.go.id/api/excel/wilayah/${_currentLevel == 4 ? 3 : _currentLevel}/$parentCode'),
          headers: {'Authorization': auth},
        );

        if (response.statusCode == 200) {
          areas = json.decode(response.body);
        } else {
          throw Exception();
        }
      }

      // 4. Process the data and update counters/state
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
          if (area == null) continue;
          
          final String kondisi = area['kondisi']?.toString().trim() ?? 'Normal';

          if (kondisi == 'Normal') {
            _panelWilayahCounterNormal += 1;
          } else if (kondisi == 'Mendekati') {
            _panelWilayahCounterMendekati += 1;
          } else if (kondisi == 'Atensi') {
            _panelWilayahCounterAtensi += 1;
          } else {
            _panelWilayahCounterNormal += 1;
          }

          _panelWilayahOptionalData.add({
            'kode': area['kode'].toString(),
            'nama': area['nama'].toString(),
            'kondisi': kondisi,
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
          break;
      }

      // Pass processing safely down to the next chain layer
      _fetchWilayahData(_currentLevel, parentCode);
      debugPrint('level now ' + _currentLevel.toString());

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

  void _rightPanelToggle() {
    if(_showMonitorButton == 'pekerjaan'){
      _fetchPekerjaanSummary('');
    }

    debugPrint("$_isShowPekerjaanPanel | $_showMonitorButton");
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

  //Future<void> _fetchWilayahData(int level, String parentCode) async {
  //  setState(() {
  //    _selectedAreaCode = parentCode;
  //    _isLoading = true;
  //  });
  //  debugPrint(_selectedAreaCode);
  //  _currentLevel = level;

  //  List<ClickablePolygon> newPolys = [];
  //  List<Marker> newMarkers = [];
  //  bool hasMissingFiles = false;

  //  String auth = 'Basic ${base64Encode(utf8.encode('aingExcel:machinegunkelly'))}';

  //  try {
  //    final response = await http.get(
  //      Uri.parse('https://geopas.satgasprr.go.id/api/excel/wilayah/${level == 4 ? 3 : level}/$parentCode'),
  //      headers: {'Authorization': auth},
  //    );

  //    if (response.statusCode == 200) {
  //      List<dynamic> areas = json.decode(response.body);

  //      for (var area in areas) {
  //        final String kode = area['kode'];
  //        final String kondisi = area['kondisi']?.toString().trim() ?? 'Normal';
  //        final String nama = area['nama'] ?? 'Unknown';

  //        try {
  //          final List<ClickablePolygon> geoData =
  //              await _parseGeoJson('assets/mapdata/$kode.geojson', kondisi, kode);

  //          if (geoData.isNotEmpty) {
  //            newPolys.addAll(geoData);
  //            LatLng centerPoint = geoData.first.center;
  //            newMarkers.add(
  //              Marker(
  //                point: centerPoint,
  //                width: 120,
  //                height: 40,
  //                child: IgnorePointer(
  //                  child: Text(
  //                    nama.replaceAll('\n', ' '),
  //                    textAlign: TextAlign.center,
  //                    style: TextStyle(
  //                      color: Colors.white,
  //                      fontSize: level >= 3 ? 8 : 10,
  //                      fontWeight: FontWeight.bold,
  //                      shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
  //                    ),
  //                  ),
  //                ),
  //              ),
  //            );
  //          }
  //        } catch (e) {
  //          hasMissingFiles = true;
  //        }
  //      }

  //      if (hasMissingFiles) {
  //        _showErrorSnippet("Beberapa data peta sub-distrik tidak ditemukan.");
  //      }
  //    }
  //  } catch (e) {
  //    _showErrorSnippet("Gagal mengambil data Level $level.");
  //  } finally {
  //    setState(() {
  //      _activePolygons = newPolys;
  //      _currentMarkers = newMarkers;
  //      _isLoading = false;
  //    });
  //  }

  //  if (_indikatorData.isNotEmpty ) {
  //    _fetchIndikatorData();
  //  }
  //}

  Future<void> _fetchWilayahData(int level, String parentCode) async {
    setState(() {
      _selectedAreaCode = parentCode;
      _isLoading = true;
    });
    debugPrint("Fetching Level: $level, Parent: $parentCode");
    _currentLevel = level;

    List<ClickablePolygon> newPolys = [];
    List<Marker> newMarkers = [];
    bool hasMissingFiles = false;

    try {
      final Directory appDataDir = await getApplicationSupportDirectory();
      final File localCacheFile = File('${appDataDir.path}/json_data/get_wilayah_all.json');

      List<dynamic> areas = [];
      bool isLoadedFromCache = false;

      if (await localCacheFile.exists()) {
        try {
          final String jsonString = await localCacheFile.readAsString();
          final List<dynamic> allCachedData = json.decode(jsonString);

          if (level == 1) {
            areas = allCachedData.where((area) => area['parent_kode'] == null).toList();
          } else {
            areas = allCachedData.where((area) {
              return area['parent_kode']?.toString().trim() == parentCode.trim();
            }).toList();
          }
          
          isLoadedFromCache = true;
          debugPrint("Successfully read and filtered ${areas.length} areas from local JSON cache.");
        } catch (cacheError) {
          debugPrint("Error parsing local cache file, falling back to API: $cacheError");
        }
      }

      if (!isLoadedFromCache) {
        debugPrint("Cache not found or failed. Directing to remote API call...");
        String auth = 'Basic ${base64Encode(utf8.encode('aingExcel:machinegunkelly'))}';
        
        final response = await http.get(
          Uri.parse('https://geopas.satgasprr.go.id/api/excel/wilayah/${level == 4 ? 3 : level}/$parentCode'),
          headers: {'Authorization': auth},
        );

        if (response.statusCode == 200) {
          areas = json.decode(response.body);
        } else {
          throw HttpException('API responded with code ${response.statusCode}');
        }
      }

      for (var area in areas) {
        if (area == null) continue;
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

    } catch (e) {
      debugPrint("Fetch execution failed error: $e");
      _showErrorSnippet("Gagal mengambil data Wilayah Level $level.");
    } finally {
      setState(() {
        _activePolygons = newPolys;
        _currentMarkers = newMarkers;
        _isLoading = false;
      });
    }

    if (_indikatorData.isNotEmpty) {
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

    if (_selectedAreaCode!.isEmpty) return;

    List<String> parts = _selectedAreaCode!.split('.');


    setState(() {
      if (parts.length > 1) {
        parts.removeLast();
        _selectedAreaCode = parts.join('.');
      } else {
        _selectedAreaCode = '';
      }
    });
    debugPrint(_selectedAreaCode);
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
                    child: Image.asset('assets/icons/logo.png', height: 42))),
            Image.asset('assets/icons/logo2.png', height: 42),
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
                    //TileLayer(
                    //  urlTemplate: _currentTileUrl,
                    //  tileProvider: CachedTileProvider(store: widget.cacheStore),
                    //),
                    TileLayer(
                      urlTemplate: _currentTileUrl,
                      userAgentPackageName: 'com.satgasprr.monitor_bencana_d',
                      tileProvider: CachedTileProvider(
                        store: widget.cacheStore,
                      ),
                      maxNativeZoom: 16, 
                      maxZoom: 18,
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
                    MobileLayerTransformer(
                      child: RepaintBoundary(
                        child: PopupMarkerLayer(
                          options: PopupMarkerLayerOptions(
                            popupController: _popupLayerController,
                            markers: [
                              ..._pekerjaanMarkers,
                              ..._pekerjaanDalrendukMarkers,
                              ..._updatedIndikatorMarkers,
                              ..._tkdMarkers,
                            ],
                            popupDisplayOptions: PopupDisplayOptions(
                              snap: PopupSnap.markerTop, 
                              builder: (BuildContext context, Marker marker) {
                                final dataPayload = (marker.key as ValueKey).value as Map<String, dynamic>;
                                //debugPrint(dataPayload.toString());
                                
                                if (dataPayload.containsKey('list_alokasi')) {
                                  return _buildTkdPopupCard(context, dataPayload);
                                }
                                
                                if (dataPayload.containsKey('foto_sebelum')) {
                                  return _buildIndikatorPopup(marker);
                                } else {
                                  return _buildDalrendukPopup(marker);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
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
                      imagePath: 'assets/icons/wilayah.png',
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
                        _pekerjaanDalrendukData.clear();
                        _pekerjaanDalrendukMarkers.clear();
                        _selectedIndikatorCategory = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    _buildSidebarButton(
                      imagePath: 'assets/icons/indikator.png',
                      label: "Update kondisi (Indikator)",
                      onTap: () {
                        setState(() {
                          _currentTileUrl = arcgisSatellite;
                          _showMonitorButton = 'update';

                          _allTkdMarkersMasterList.clear();
                          _tkdMarkers.clear();
                          _tkdData.clear();
                          _pekerjaanDalrendukData.clear();
                          _pekerjaanDalrendukMarkers.clear();
                        });
                        _fetchIndikatorData();
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildSidebarButton(
                      imagePath: 'assets/icons/pekerjaan.png',
                      label: "DalRenduk",
                      onTap: () => setState(() {
                        setState(() {
                          _indikatorData.clear();
                          _allIndikatorMarkersMasterList.clear();
                          _updatedIndikatorMarkers.clear();

                          _allTkdMarkersMasterList.clear();
                          _tkdMarkers.clear();
                          _tkdData.clear();
                          _selectedIndikatorCategory = null;
                        });

                        _currentTileUrl = arcgisDefault;
                        _showMonitorButton = 'pekerjaan'; 
                        _fetchPekerjaanSummary('');
                        //_rightPanelToggle();
                      }),
                    ),
                    const SizedBox(height: 16),
                    _buildSidebarButton(
                      imagePath: 'assets/icons/tkd.png',
                      label: "TKD",
                      onTap: () => setState(() {
                        _fetchTkdData();

                        _indikatorData.clear();
                        _allIndikatorMarkersMasterList.clear();
                        _updatedIndikatorMarkers.clear();

                        _pekerjaanDalrendukData.clear();
                        _pekerjaanDalrendukMarkers.clear();

                        _showMonitorButton = 'tkd';
                        _currentTileUrl = arcgisSatellite;
                        _selectedIndikatorCategory = null;
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

          //ElevatedButton.icon(
          //  style: ElevatedButton.styleFrom(
          //    backgroundColor: const Color(0xFF22467a),
          //    foregroundColor: Colors.white,
          //    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          //    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          //  ),
          //  icon: const Icon(Icons.download_for_offline, size: 16, color: Colors.cyanAccent),
          //  label: const Text("Unduh Data Offline", style: TextStyle(fontSize: 11)),
          //  onPressed: _downloadAllJson,
          //),

          Positioned(
            bottom: 50,
            right: 70,
            child: FloatingActionButton.extended(
              onPressed: _downloadAllJson,
              label: const Text("Unduh data"),
              icon: const Icon(Icons.download),
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
                          child: AppImage(
                            _getAssetPath('assets/icons/database_${_showMonitorButton == 'wilayah' ? 'wilayah' : _showMonitorButton == 'update' ? 'indikator' : _showMonitorButton == 'pekerjaan' ? 'pekerjaan' : 'tkd'}.png'),
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

          if (_isShowUpdatePanel)
            Positioned(
              top: 10,
              right: 40,
              child: Container(
                width: 520,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF231608),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER SECTION
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Text(
                            "Kondisi dan Progress Indikator Pemulihan Pemerintahan dan Kemasyarakatan yang Terdampak Bencana",
                            style: TextStyle(
                              color: Color(0xFFE5E5E5),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => setState(() => _isShowUpdatePanel = false),
                          icon: const Icon(Icons.close, color: Colors.white60, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // DROPDOWNS ROW
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

                                if (newId != null && newId != '0' && newId != 'All') {
                                  _selectedProvinceId = newId;
                                } else {
                                  _selectedProvinceId = null; 
                                }
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
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 35,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              border: Border.all(color: Colors.white10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Kec : $_selectedOptionKecamatan", 
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // SCROLLABLE LIST OF INDICATORS
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.65,
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          scrollbarTheme: ScrollbarThemeData(
                            thumbColor: WidgetStateProperty.all(Colors.white30),
                            trackColor: WidgetStateProperty.all(Colors.white10),
                            interactive: true,
                          ),
                        ),
                        child: Scrollbar(
                          controller: _panelScrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          thickness: 4.0,
                          child: ListView.separated(
                            controller: _panelScrollController,
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _panelIndikatorData.length,
                            separatorBuilder: (context, index) => const Divider(
                              color: Colors.white10,
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final item = _panelIndikatorData[index];
                              return _buildProgressIndicatorRow(item);
                            },
                          ),
                        ),
                      ),
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
                                }
                              });
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
                                Text("$_selectedOptionKabupaten", style: const TextStyle(color: Colors.white, fontSize: 11)),
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
                                Text("$_selectedOptionKecamatan", style: const TextStyle(color: Colors.white, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white10),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Builder(
                          builder: (context) {
                            List<dynamic> displayList = [];
                            if (_selectedOptionProv == null || _selectedOptionProv == 'All' || _selectedOptionProv == '') {
                              displayList = List.from(_tkdData);
                            } else {
                              displayList = _tkdData.where((item) {
                                final wilayah = item['wilayah'] ?? {};
                                return wilayah['parent_kode']?.toString() == _selectedOptionProv.toString() ||
                                       wilayah['kode']?.toString() == _selectedOptionProv.toString();
                              }).toList();
                            }

                            String formatRawNum(dynamic val) {
                              if (val == null) return "0";
                              double numVal = double.tryParse(val.toString()) ?? 0.0;
                              RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
                              return numVal.toStringAsFixed(0).replaceAllMapped(reg, (Match match) => '${match[1]},');
                            }

                            return Column(
                              children: [
                                Container(
                                  color: Colors.white.withOpacity(0.05),
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  child: const Row(
                                    children: [
                                      Expanded(flex: 1, child: Text("No", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                                      Expanded(flex: 3, child: Text("Pemerintah daerah", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                                      Expanded(flex: 2, child: Text("TKD 2026", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                                      Expanded(flex: 2, child: Text("Penyesuaian TKD 2026", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                                      Expanded(flex: 3, child: Text("Total TKD setelah penyesuaian", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                ),
                                
                                Expanded(
                                  child: displayList.isEmpty
                                      ? const Center(
                                          child: Text(
                                            "Tidak ada data TKD tersedia untuk filter ini.",
                                            style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
                                          ),
                                        )
                                      : ListView.separated(
                                          padding: EdgeInsets.zero,
                                          itemCount: displayList.length,
                                          separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                                          itemBuilder: (context, index) {
                                            final rowItem = displayList[index];
                                            final wilayah = rowItem['wilayah'] ?? {};
                                            
                                            double ang2026 = double.tryParse(rowItem['anggaran_2026']?.toString() ?? '0') ?? 0.0;
                                            double penyesuaian = double.tryParse(rowItem['penyesuaian']?.toString() ?? '0') ?? 0.0;
                                            double totalAkhir = ang2026 + penyesuaian;

                                            return Container(
                                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                              color: index % 2 == 0 ? Colors.transparent : Colors.white.withOpacity(0.02),
                                              child: Row(
                                                children: [
                                                  Expanded(flex: 1, child: Text("${index + 1}", style: const TextStyle(color: Colors.white70, fontSize: 11))),
                                                  Expanded(flex: 3, child: Text(wilayah['nama'] ?? '-', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                                  Expanded(flex: 2, child: Text(formatRawNum(ang2026), style: const TextStyle(color: Colors.white70, fontSize: 11))),
                                                  Expanded(flex: 2, child: Text(formatRawNum(penyesuaian), style: const TextStyle(color: Colors.amberAccent, fontSize: 11))),
                                                  Expanded(flex: 3, child: Text(formatRawNum(totalAkhir), style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
  
          if (_isShowDalrendukPanel)
            Positioned(
              top: 10,
              right: 40,
              child: Container(
                width: 1300,
                height: 780,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0F14).withOpacity(0.96),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white10,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT SIDEBAR
                        Container(
                          width: 260,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white10,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'No.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),

                              const SizedBox(height: 2),

                              const Text(
                                'Terbersihkannya objek ODCB',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),

                              const Text(
                                '-',
                                style: TextStyle(
                                  color: Colors.white54,
                                ),
                              ),

                              const SizedBox(height: 18),

                              Container(
                                height: 18,
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),

                              const SizedBox(height: 22),

                              _menuItem(
                                title: 'Grafik Pekerjaan',
                                selected: selectedTab == 0,
                                onTap: () {
                                  setState(() {
                                    selectedTab = 0;
                                  });
                                },
                              ),

                              _menuItem(
                                title: 'Informasi',
                                selected: selectedTab == 1,
                                onTap: () {
                                  setState(() {
                                    selectedTab = 1;
                                  });
                                },
                              ),

                              _menuItem(
                                title: 'Penyedia',
                                selected: selectedTab == 2,
                                onTap: () {
                                  setState(() {
                                    selectedTab = 2;
                                  });
                                },
                              ),

                              _menuItem(
                                title: 'Rincian',
                                selected: selectedTab == 3,
                                onTap: () {
                                  setState(() {
                                    selectedTab = 3;
                                  });
                                },
                              ),

                              _menuItem(
                                title: 'Timeline',
                                selected: selectedTab == 4,
                                onTap: () {
                                  setState(() {
                                    selectedTab = 4;
                                  });
                                },
                              ),

                              _menuItem(
                                title: 'Realisasi',
                                selected: selectedTab == 5,
                                onTap: () {
                                  setState(() {
                                    selectedTab = 5;
                                  });
                                },
                              ),

                              _menuItem(
                                title: 'Pembayaran',
                                selected: selectedTab == 6,
                                onTap: () {
                                  setState(() {
                                    selectedTab = 6;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // RIGHT CONTENT
                        //Expanded(
                        //  child: Column(
                        //    children: [
                        //      Row(
                        //        children: [
                        //          Expanded(
                        //            child: _topCard(
                        //              title: 'Realisasi Keuangan',
                        //              value: 'Rp. 0',
                        //            ),
                        //          ),

                        //          const SizedBox(width: 18),

                        //          Expanded(
                        //            child: _topCard(
                        //              title: 'Realisasi Fisik',
                        //              value: '-',
                        //            ),
                        //          ),

                        //          const SizedBox(width: 18),

                        //          Expanded(
                        //            child: _topCard(
                        //              title: 'Realisasi Waktu',
                        //              value: '-',
                        //            ),
                        //          ),
                        //        ],
                        //      ),

                        //      const SizedBox(height: 18),

                        //      Container(
                        //        width: double.infinity,
                        //        height: 120,
                        //        padding: const EdgeInsets.all(20),
                        //        decoration: BoxDecoration(
                        //          borderRadius: BorderRadius.circular(14),
                        //          border: Border.all(
                        //            color: Colors.white10,
                        //          ),
                        //        ),
                        //        child: const Column(
                        //          crossAxisAlignment: CrossAxisAlignment.start,
                        //          children: [
                        //            Text(
                        //              'Grafik Realisasi Terharap Timeline',
                        //              style: TextStyle(
                        //                color: Colors.white,
                        //                fontSize: 18,
                        //              ),
                        //            ),

                        //            SizedBox(height: 8),

                        //            Text(
                        //              '-',
                        //              style: TextStyle(
                        //                color: Colors.white54,
                        //                fontSize: 18,
                        //              ),
                        //            ),
                        //          ],
                        //        ),
                        //      ),
                        //    ],
                        //  ),
                        //),
                        Expanded(
                          child: _buildTabContent(),
                        ),
                      ],
                    ),

                    // CLOSE BUTTON
                    Positioned(
                      top: 0,
                      right: 0,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isShowDalrendukPanel = false;                          
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            color: Color(0xFFD2A86A),
                            size: 22,
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
    );
  }
}

//void parseIndikatorJsonIsolate(Map<String, dynamic> params) {
//  final String rawJson = params['jsonString'];
//  final SendPort sendPort = params['sendPort'];

//  try {
//    final Map<String, dynamic> decodedData = json.decode(rawJson);
//    final List<dynamic> listIndikator = decodedData['list_indikator'] ?? [];

//    List<dynamic> chunkBatch = [];

//    for (var indikator in listIndikator) {
//      List<dynamic> listSektor = indikator['list_sektor_terdampak'] ?? [];
//      for (var sektor in listSektor) {
        
//        double? lat = double.tryParse(sektor['latitude']?.toString() ?? '');
//        double? lng = double.tryParse(sektor['longitude']?.toString() ?? '');

//        if (lat != null && lng != null) {
//          chunkBatch.add(sektor);

//          if (chunkBatch.length >= 20) {
//            sendPort.send(List.from(chunkBatch));
//            chunkBatch.clear();
//          }
//        }
//      }
//    }

//    if (chunkBatch.isNotEmpty) {
//      sendPort.send(chunkBatch);
//    }
//  } catch (e) {
//    sendPort.send({'isolate_error': e.toString()});
//  } finally {
//    sendPort.send('DONE');
//  }
//}

void parseIndikatorJsonIsolate(Map<String, dynamic> params) {
  final String rawJson = params['jsonString'];
  final SendPort sendPort = params['sendPort'];

  try {
    final Map<String, dynamic> decodedData = json.decode(rawJson);
    final List<dynamic> listIndikator = decodedData['list_indikator'] ?? [];

    List<dynamic> chunkBatch = [];

    for (var indikator in listIndikator) {
      // 1. Get the parent indicator's title name
      final String parentIndikatorNama = (indikator['nama'] ?? '').toString().trim();
      
      List<dynamic> listSektor = indikator['list_sektor_terdampak'] ?? [];
      for (var sektor in listSektor) {
        
        double? lat = double.tryParse(sektor['latitude']?.toString() ?? '');
        double? lng = double.tryParse(sektor['longitude']?.toString() ?? '');

        if (lat != null && lng != null) {
          // ===================================================================
          // NEW STEP: Inject parent title name into the map object
          // ===================================================================
          sektor['parent_indikator_nama'] = parentIndikatorNama;

          chunkBatch.add(sektor);

          if (chunkBatch.length >= 20) {
            sendPort.send(List.from(chunkBatch));
            chunkBatch.clear();
          }
        }
      }
    }

    // Flush any remaining items in the buffer
    if (chunkBatch.isNotEmpty) {
      sendPort.send(List.from(chunkBatch));
      chunkBatch.clear();
    }

    sendPort.send('DONE');
  } catch (e) {
    sendPort.send({'isolate_error': e.toString()});
  }
}