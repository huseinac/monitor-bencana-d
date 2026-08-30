import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:latlong2/latlong.dart';
import '../models/pekerjaan_model.dart';

import '../controllers/wilayah_selection_controller.dart';

List<PelaksanaModel> _parsePelaksanaIsolate(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    throw Exception("File not found at $filePath");
  }

  final jsonString = file.readAsStringSync();
  final List<dynamic> decodedRoot = json.decode(jsonString);

  final List<PelaksanaModel> pelaksanaList = PelaksanaModel.listFromJson(decodedRoot);

  return pelaksanaList;
}

List<PekerjaanModel> _parsePekerjaanIsolate(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    throw Exception("File not found at $filePath");
  }

  final jsonString = file.readAsStringSync();
  final List<dynamic> decodedRoot = json.decode(jsonString);

  final List<PelaksanaModel> pelaksanaList = PelaksanaModel.listFromJson(decodedRoot);

  final List<PekerjaanModel> extractedList = [];
  for (var pelaksana in pelaksanaList) {
    extractedList.addAll(pelaksana.listPekerjaan);
  }

  return extractedList;
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

class MarkerConfig {
  final int id;
  final double latitude;
  final double longitude;
  final String fullLocalPath;

  MarkerConfig({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.fullLocalPath,
  });
}

class MapMarkerWidget extends StatelessWidget {
  final String imagePath;

  const MapMarkerWidget({
    super.key,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            blurRadius: 3,
            offset: Offset(0, 1),
          )
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.0),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(1),
        child: ClipOval(
          child: AppImage(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.location_on,
              color: Colors.red,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

List<MarkerConfig> _generateMarkerConfigsIsolate(Map<String, dynamic> params) {
  final List<dynamic> rawFiltered = params['filteredPekerjaan'];
  final String baseDir = params['baseDir'];

  final List<MarkerConfig> configs = [];

  for (var raw in rawFiltered) {
    final double? lat = double.tryParse(raw['latitude']?.toString() ?? '');
    final double? lng = double.tryParse(raw['longitude']?.toString() ?? '');
    final num? progress = num.tryParse(raw['persentase']?.toString() ?? '');
    final int indId = raw['indikatorId'] is int
        ? raw['indikatorId'] as int
        : int.tryParse(raw['indikatorId']?.toString() ?? '') ?? 0;
    final String indicatorName = raw['nama']?.toString() ?? '-';
    final int? id = raw['id'] is int
        ? raw['id'] as int
        : int.tryParse(raw['id']?.toString() ?? '');

    if (lat == null || lng == null || progress == null || id == null) continue;

    String markerImage = 'help';

    if (indId == 2 || indId == 3 || indId == 4 || indId == 5 || indId == 34) {
      markerImage = 'building';
    } else if (indId == 8 || indId == 10 || indId == 11 || indId == 12) {
      markerImage = 'health';
    } else if (indId == 13 || indId == 14 || indId == 16 || indId == 17 || indId == 18 || indId == 19) {
      markerImage = 'school';
    } else if (indId == 21 || indId == 22 || indId == 24 || indId == 25 || indId == 26) {
      markerImage = 'road';
    } else if (indicatorName.contains('Jembatan')) {
      markerImage = 'bride';
    } else if (indId == 37) {
      markerImage = 'electric';
    } else if (indId == 38) {
      markerImage = 'water';
    } else if (indId == 35) {
      markerImage = 'religion';
    } else if (indId == 41 || indId == 43) {
      markerImage = 'river';
    } else if (['Huntara', 'Huntap'].any(indicatorName.contains)) {
      markerImage = 'home';
    } else if (indId == 44 || indId == 45 || indId == 46) {
      markerImage = 'homes';
    } else if (indId == 36) {
      markerImage = 'gas_station';
    } else if (indId == 40) {
      markerImage = 'gas';
    } else if (indId == 27 || indId == 31 || indId == 32 || indId == 48) {
      markerImage = 'store';
    }

    if (progress <= 40) {
      markerImage += '-yellow';
    } else if (progress > 40 && progress <= 70) {
      markerImage += '-blue';
    } else if (progress > 70 && progress <= 100) {
      markerImage += '-green';
    } else {
      markerImage += '-red';
    }
    markerImage += '.png';

    final String imageRelativePath =
        'assets/icons/$markerImage'.replaceAll('/', Platform.pathSeparator);
    final String fullLocalPath = '$baseDir$imageRelativePath';

    configs.add(MarkerConfig(
      id: id,
      latitude: lat,
      longitude: lng,
      fullLocalPath: fullLocalPath,
    ));
  }

  return configs;
}

class PekerjaanController extends ChangeNotifier {
  final PopupController _popupLayerController = PopupController();
  PopupController get popupLayerController => _popupLayerController;
  WilayahSelectionController? _wilayah;

  List<PekerjaanModel> allPekerjaanData = [];
  List<PekerjaanModel> filteredPekerjaanData = [];

  List<PelaksanaModel> allPelaksanaData = [];
  List<PelaksanaModel> filteredPelaksanaData = [];

  String? _filterNama;
  String? _filterProvinsiId;
  String? _filterKabupatenId;
  String? _filterKecamatanId;
  int? _filterPelaksanaId;
  int? _filterStatusAnggaranId;
  int? _filterPelaksanaanId;
  int? _filterIndikatorId;
  int? _filterKategoriPekerjaanId;
  int? _filterId;

  String? get filterNama => _filterNama;
  String? get filterProvinsiId => _filterProvinsiId;
  int? get filterPelaksanaId => _filterPelaksanaId;
  int? get filterId => _filterId;

  String? _filterTahunAnggaran;
  String? get filterTahunAnggaran => _filterTahunAnggaran;

  int? _highlightedPekerjaanId;
  int? get highlightedPekerjaanId => _highlightedPekerjaanId;

  PekerjaanModel? _selectedDetailData;
  PekerjaanModel? get selectedDetailData => _selectedDetailData;

  bool _isDetailPanelVisible = false;
  bool get isDetailPanelVisible => _isDetailPanelVisible;

  void showDetailPanel(PekerjaanModel data) {
    _selectedDetailData = data;
    _isDetailPanelVisible = true;
    notifyListeners();
  }

  void hideDetailPanel() {
    _selectedDetailData = null;
    _isDetailPanelVisible = false;
    notifyListeners();
  }

  void filterByNama(String? nama) {
    _filterNama = (nama == null || nama.trim().isEmpty) ? null : nama.trim();
    _applyFilters();
  }

  void updateWilayahSelection(WilayahSelectionController wilayahSelection) {
    _wilayah = wilayahSelection;
  }

  void filterByProvinsiId(String? provinsiId) {
    _filterProvinsiId = (provinsiId == null || provinsiId == '0') ? null : provinsiId;
    _applyFilters();
  }

  void filterByKabupatenId(String? kabuId) {
    _filterKabupatenId = (kabuId == null || kabuId == '0') ? null : kabuId;
    _applyFilters();
  }

  void filterByKecamatanId(String? kecId) {
    _filterKecamatanId = (kecId == null || kecId == '0') ? null : kecId;
    _applyFilters();
  }

  void filterByStatusAnggaranId(int? saId) {
    _filterStatusAnggaranId = (saId == null || saId == 0) ? null : saId;
    _applyFilters();
  }

  void filterByStatusPelaksanaanId(int? spId) {
    _filterPelaksanaanId = (spId == null || spId == 0) ? null : spId;
    _applyFilters();
  }

  void filterByIndikatorId(int? inId) {
    _filterIndikatorId = (inId == null || inId == 0) ? null : inId;
    _applyFilters();
  }

  void filterByKategoriPekerjaanId(int? kpId) {
    _filterKategoriPekerjaanId = (kpId == null || kpId == 0) ? null : kpId;
    _applyFilters();
  }

  void filterByPelaksanaId(int? pelaksanaId) {
    _filterPelaksanaId = pelaksanaId;
    clearHighlight();
    _applyFilters();
  }

  void filterByTahunAnggaran(String? tahun) {
    _filterTahunAnggaran = (tahun == null || tahun.trim().isEmpty) ? null : tahun.trim();
    _applyFilters();
  }

  void filterById(int? id) {
    _filterId = (id == null ? null : id);
    _applyFiltersById();
  }

  Future<void> _applyFiltersById() async {
    Iterable<PekerjaanModel> result = allPekerjaanData;
    if (_filterId != null) {
      result = result.where((p) => (p.id ?? '') == filterId);
    }

    filteredPekerjaanData = result.toList();
    await generateMarkers();
  }

  void clearFilters() {
    _filterNama = null;
    _filterProvinsiId = null;
    _filterKabupatenId = null;
    _filterKecamatanId = null;
    _filterPelaksanaId = null;
    _filterTahunAnggaran = null;
    _filterStatusAnggaranId = null;
    _filterPelaksanaanId = null;
    _filterIndikatorId = null;
    _filterKategoriPekerjaanId = null;
    clearHighlight();
    _applyFilters();
  }

  Future<void> _applyFilters() async {
    Iterable<PekerjaanModel> result = allPekerjaanData;

    if (_filterProvinsiId != null) {
      final matchedProvince = _wilayah?.wilayah.data
          .firstWhereOrNull((w) => w.kode == _filterProvinsiId);
      final resolvedId = matchedProvince?.id;
      result = result.where((p) => p.provinsiId == resolvedId);
    }
    if (_filterKabupatenId != null) {
      final matchedKabu = _wilayah?.wilayah.data
          .firstWhereOrNull((w) => w.kode == _filterKabupatenId);
      final resolvedId = matchedKabu?.id;
      result = result.where((p) => p.kabupatenId == resolvedId);
    }
    if (_filterKecamatanId != null) {
      final matchedKec = _wilayah?.wilayah.data
          .firstWhereOrNull((w) => w.kode == _filterKecamatanId);
      final resolvedId = matchedKec?.id;
      result = result.where((p) => p.wilayahId == resolvedId);
    }
    if (_filterStatusAnggaranId != null) {
      result = result.where((p) => p.statusAnggaranId == _filterStatusAnggaranId);
    }
    if (_filterPelaksanaanId != null) {
      result = result.where((p) => p.statusPelaksanaanId == _filterPelaksanaanId);
    }
    if (_filterIndikatorId != null) {
      result = result.where((p) => p.indikatorId == _filterIndikatorId);
    }
    if (_filterKategoriPekerjaanId != null) {
      result = result.where((p) => p.kategoriPaketPekerjaanId == _filterKategoriPekerjaanId);
    }
    if (_filterPelaksanaId != null) {
      result = result.where((p) => p.pelaksanaId == _filterPelaksanaId);
    }
    if (_filterTahunAnggaran != null) {
      result = result.where((p) => p.tahunAnggaran == _filterTahunAnggaran);
    }
    if (_filterNama != null) {
      final lower = _filterNama!.toLowerCase();
      result = result.where((p) => (p.nama ?? '').toLowerCase().contains(lower));
    }

    filteredPekerjaanData = result.toList();
    await generateMarkers();
  }

  void highlightPekerjaan(int? id) {
    if (_highlightedPekerjaanId == id) return;
    _highlightedPekerjaanId = id;
    notifyListeners();
  }

  void clearHighlight() {
    if (_highlightedPekerjaanId == null) return;
    _highlightedPekerjaanId = null;
    notifyListeners();
  }

  List<Marker> _markers = [];

  bool _markersVisible = false;
  bool get markersVisible => _markersVisible;
  List<Marker> get markers => _markersVisible ? _markers : const [];

  void setMarkersVisible(bool visible) {
    if (_markersVisible == visible) return;
    _markersVisible = visible;
    notifyListeners();
  }

  bool _isLoaded = false;
  String? _error;

  List<PekerjaanModel> get data => allPekerjaanData;
  bool get isLoaded => _isLoaded;
  String? get error => _error;
  bool get hasData => allPekerjaanData.isNotEmpty;

  PekerjaanController();

  Future<void> loadPekerjaanData({bool forceReload = false}) async {
    if (_isLoaded && !forceReload) {
      debugPrint('Pekerjaan data already loaded, skipping...');
      return;
    }

    if (!Platform.isWindows) {
      throw UnsupportedError("This path resolution is specific to Windows.");
    }

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null) {
      throw Exception("Could not find USERPROFILE environment variable.");
    }

    final String targetPath =
        '$userProfile\\AppData\\Roaming\\SatgasPRR\\monitor_bencana_d\\json_data\\get_pekerjaan.json';

    try {
      _error = null;
      notifyListeners();

      debugPrint('Loading pekerjaan data from: $targetPath');

      List<PelaksanaModel> result1 =
          await Isolate.run(() => _parsePelaksanaIsolate(targetPath));

      allPelaksanaData = result1;
      filteredPelaksanaData = result1;

      List<PekerjaanModel> result2 =
          await Isolate.run(() => _parsePekerjaanIsolate(targetPath));

      allPekerjaanData = result2;
      filteredPekerjaanData = result2;

      if (_wilayah?.selectedProv != '0') {
        filterByProvinsiId(_wilayah?.selectedProv);
      }

      _isLoaded = true;

      await generateMarkers();

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoaded = false;
      notifyListeners();
      debugPrint("Error reading/parsing Pekerjaan JSON: $e");
      rethrow;
    }
  }

  Widget buildPopupForMarker(BuildContext context, Marker marker) {
    final id = (marker.key as ValueKey).value as int;
    if (filteredPekerjaanData.length < 1) return const SizedBox.shrink();

    final selectedData = allPekerjaanData.firstWhere((p) => (p.id ?? '') == id);
    return _buildPopupInfo(context, selectedData);
  }

  Widget _buildPopupInfo(BuildContext context, PekerjaanModel data) {
    final currentWilayah = _wilayah?.wilayah.data.firstWhereOrNull(
      (w) => w.id == data.wilayahId,
    );

    String kecamatan = currentWilayah?.nama ?? '';
    String kabupaten = '';
    String provinsi = '';

    if (currentWilayah != null) {
      final parentWilayah = _wilayah?.wilayah.data.firstWhereOrNull(
        (w) => w.kode == currentWilayah.parentKode,
      );
      kabupaten = parentWilayah?.nama ?? '';

      if (parentWilayah != null) {
        final grandParentWilayah = _wilayah?.wilayah.data.firstWhereOrNull(
          (w) => w.kode == parentWilayah.parentKode,
        );
        provinsi = grandParentWilayah?.nama ?? '';
      }
    }
    
    String namaSektor = data.nama ?? '-';
    
    String formatRupiah(dynamic rawValue) {
      if (rawValue == null) return 'Rp. 0';
      String digitsOnly = rawValue.toString().replaceAll(RegExp(r'[^0-9]'), '');
      if (digitsOnly.isEmpty) return 'Rp. 0';
      final intValue = int.tryParse(digitsOnly) ?? 0;
      final RegExp regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      String formatted = intValue.toString().replaceAllMapped(regex, (Match m) => '${m[1]}.');
      return 'Rp. $formatted';
    }

    String nominal = formatRupiah(data.nominal);

    String markerImage = '';
    if (data.nama!.contains('Kantor')) {
        markerImage = 'building';
    } else if (data.nama!.contains('Faskes')) {
        markerImage = 'health';
    } else if (
        data.nama!.contains('PAUD') ||
        data.nama!.contains('TK') ||
        data.nama!.contains('SD') ||
        data.nama!.contains('SMP') ||
        data.nama!.contains('SMA/SMK') ||
        data.nama!.contains('Madrasah/Ponpes')
      ) {
        markerImage = 'school';
    } else if (data.nama!.contains('Jalan')) {
        markerImage = 'road';
    } else if (data.nama!.contains('Jembatan')) {
        markerImage = 'bride';
    } else if (data.nama!.contains('Kelistrikan')) {
        markerImage = 'electric';
    } else if (data.nama!.contains('PDAM/SPAM')) {
        markerImage = 'water';
    } else if (data.nama!.contains('Gedung Rumah Ibadah')) {
        markerImage = 'religion';
    } else if (data.nama!.contains('Sungai')) {
        markerImage = 'river';
    } else if (
        data.nama!.contains('Huntara') ||
        data.nama!.contains('Huntap')
      ) {
        markerImage = 'home';
    } else if (data.nama!.contains('Pengungsian')) {
        markerImage = 'homes';
    } else if (
        data.nama!.contains('toko diluar pasar') ||
        data.nama!.contains('Hotel/Penginapan')
      ) {
        markerImage = 'building';
    } else if (data.nama!.contains('SPBU')) {
        markerImage = 'gas_station';
    } else if (data.nama!.contains('Gas LPG')) {
        markerImage = 'gas';
    } else if (
        data.nama!.contains('Gedung/Sarpras Pasar') ||
        data.nama!.contains('Gedung/Sarpras Resto/Warung/Kafe/kedai') ||
        data.nama!.contains('Koperasi')
      ) {
        markerImage = 'store';
    } else if (data.nama!.contains('INTERNET')) {
        markerImage = 'help';
    } else if (
        data.nama!.contains('Persawahan') ||
        data.nama!.contains('Perikanan (Tambak)')
      ) {
        markerImage = 'river';
    } else if (
        data.nama!.contains('Pembersihan lumpur') ||
        data.nama!.contains('DTH')
      ) {
        markerImage = 'help';
    }
    markerImage += '.png';

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

    Widget buildActionButton(String label, IconData icon, VoidCallback onTap, {bool isActive = false}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3.0),
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
              backgroundColor: isActive ? const Color(0xFF0F172A) : const Color(0xFF334155),
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
        color: const Color(0xFF1E293B),
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

          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildMetaRow("Provinsi", provinsi),
                buildMetaRow("Kabupaten", kabupaten),
                buildMetaRow("Kecamatan", kecamatan),
                buildMetaRow("Nominal Pekerjaan", nominal, valueColor: const Color(0xFF60A5FA)),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                buildActionButton("Detail", Icons.info_outline, () {
                  _popupLayerController.hideAllPopups();
                  showDetailPanel(data);
                }),
                buildActionButton("Dokumentasi", Icons.camera_alt_outlined, () {
                }),
                buildActionButton("Progres", Icons.trending_up, () {
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getAssetPath(String relativePath) {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null) {
    throw Exception("Could not find USERPROFILE environment variable.");
    }
    final String combinedPath = '$userProfile\\AppData\\Roaming\\SatgasPRR\\monitor_bencana_d\\$relativePath';

    final String fullLocalPath = combinedPath.replaceAll('/', Platform.pathSeparator).replaceAll('\\', Platform.pathSeparator);

    if (File(fullLocalPath).existsSync()) {
    return fullLocalPath;
    }

    return relativePath;
  }

  Future<void> generateMarkers() async {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null) return;

    final String baseDir = '$userProfile\\AppData\\Roaming\\SatgasPRR\\monitor_bencana_d\\'
        .replaceAll('/', Platform.pathSeparator)
        .replaceAll('\\', Platform.pathSeparator);

    final List<Map<String, dynamic>> securePayloadList = filteredPekerjaanData
        .map((p) => {
              'id': p.id,
              'latitude': p.latitude,
              'longitude': p.longitude,
              'persentase': p.persentase,
              'indikatorId': p.indikatorId,
              'nama': p.nama,
            })
        .toList();

    try {
      final List<MarkerConfig> computedConfigs = await Isolate.run(
        () => _generateMarkerConfigsIsolate({
          'filteredPekerjaan': securePayloadList,
          'baseDir': baseDir,
        }),
      );

      _markers = computedConfigs.map((config) {
        return Marker(
          key: ValueKey(config.id),
          point: LatLng(config.latitude, config.longitude),
          width: 28,
          height: 28,
          child: MapMarkerWidget(imagePath: config.fullLocalPath),
        );
      }).toList();

      debugPrint('Generated ${_markers.length} pekerjaan markers '
          '(from ${securePayloadList.length} candidates)');

      notifyListeners();
    } catch (e) {
      debugPrint("Error generating markers in background isolate: $e");
    }
  }

  void clearData() {
    allPelaksanaData = [];
    allPekerjaanData = [];
    _markers = [];
    _isLoaded = false;
    _error = null;
    notifyListeners();
  }

  void clearFilteredData() {
    filteredPekerjaanData = [];
    notifyListeners();
  }
}