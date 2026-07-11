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
import '../models/pekerjaan_model.dart'; // Make sure this path points to your model

import '../controllers/wilayah_selection_controller.dart';

/// Top-level flat extraction function running safely inside the Isolate background worker.
/// It iterates over the container lists and flattens every array found inside 'list_pekerjaan'.
List<PelaksanaModel> _parsePelaksanaIsolate(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    throw Exception("File not found at $filePath");
  }

  final jsonString = file.readAsStringSync();
  final List<dynamic> decodedRoot = json.decode(jsonString);

  // Parse using your new data model array function
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

  // Parse using your new data model array function
  final List<PelaksanaModel> pelaksanaList = PelaksanaModel.listFromJson(decodedRoot);

  // Safely flatten all PekerjaanModel items inside every pelaksana structure
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
    // Avoid heavy runtime styling computations inside the list loop
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        shape: BoxShape.circle,
        // Using simplified box-shadow profiles for high-volume mapping layers
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

/// Runs inside a background isolate. `params['filteredPekerjaan']` is a list
/// of plain maps built from PekerjaanModel (see `generateMarkers` below) —
/// NOTE: on the model, `latitude`/`longitude` are Strings and `persentase`
/// is a `num` (int or double), so everything here is parsed defensively
/// rather than cast directly.
List<MarkerConfig> _generateMarkerConfigsIsolate(Map<String, dynamic> params) {
  final List<dynamic> rawFiltered = params['filteredPekerjaan'];
  final String baseDir = params['baseDir'];

  final List<MarkerConfig> configs = [];

  for (var raw in rawFiltered) {
    // latitude/longitude come in as Strings — parse them, don't cast them.
    final double? lat = double.tryParse(raw['latitude']?.toString() ?? '');
    final double? lng = double.tryParse(raw['longitude']?.toString() ?? '');
    // persentase can be int or double at runtime — num.tryParse covers both.
    final num? progress = num.tryParse(raw['persentase']?.toString() ?? '');
    final int indId = raw['indikatorId'] is int
        ? raw['indikatorId'] as int
        : int.tryParse(raw['indikatorId']?.toString() ?? '') ?? 0;
    // The payload key is 'nama', not 'namaLokasi'.
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
  int? _filterPelaksanaId;
  int? _filterId;

  String? get filterNama => _filterNama;
  String? get filterProvinsiId => _filterProvinsiId;
  int? get filterPelaksanaId => _filterPelaksanaId;
  int? get filterId => _filterId;

  String? _filterTahunAnggaran;
  String? get filterTahunAnggaran => _filterTahunAnggaran;

  // --- Single-marker highlight (detail click) ---
  int? _highlightedPekerjaanId;
  int? get highlightedPekerjaanId => _highlightedPekerjaanId;

  PekerjaanModel? _selectedDetailData;
  PekerjaanModel? get selectedDetailData => _selectedDetailData;

  bool _isDetailPanelVisible = false;
  bool get isDetailPanelVisible => _isDetailPanelVisible;

  void showDetailPanel(PekerjaanModel data) {
    _selectedDetailData = data; // Store the clicked model instance
    _isDetailPanelVisible = true;
    notifyListeners();
  }

  void hideDetailPanel() {
    _selectedDetailData = null; // Clear it out when hidden
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

  void filterByPelaksanaId(int? pelaksanaId) {
    _filterPelaksanaId = pelaksanaId;
    clearHighlight(); // switching pelaksana invalidates any single-marker highlight
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
    _filterPelaksanaId = null;
    _filterTahunAnggaran = null;
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

  /// Show only one marker (matching id) on the map, hiding the rest of the
  /// currently-filtered set. Does NOT touch _markers/filteredPekerjaanData —
  /// purely a display-level narrowing, so it's instant (no isolate work).
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

  // Controls whether `markers` exposes the computed marker list or an
  // empty one — lets HomeView hide the pekerjaan layer whenever its panel
  // isn't the one currently open, without throwing away the computed data.
  bool _markersVisible = false;
  bool get markersVisible => _markersVisible;
  List<Marker> get markers => _markersVisible ? _markers : const [];

  void setMarkersVisible(bool visible) {
    if (_markersVisible == visible) return;
    _markersVisible = visible;
    notifyListeners();
  }

  // Loading states
  bool _isLoaded = false;
  String? _error;

  // Getters
  List<PekerjaanModel> get data => allPekerjaanData;
  bool get isLoaded => _isLoaded;
  String? get error => _error;
  bool get hasData => allPekerjaanData.isNotEmpty;

  PekerjaanController();

  /// Loads full flattened data once or handles manual reloading flags
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

    // Windows custom path resolution matching SatgasPRR local architecture
    final String targetPath =
        '$userProfile\\AppData\\Roaming\\SatgasPRR\\monitor_bencana_d\\json_data\\get_pekerjaan.json';

    try {
      _error = null;
      notifyListeners();

      debugPrint('Loading pekerjaan data from: $targetPath');

      // Execute the compute/isolate loop on background pool
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
      // 2. Find the kabupaten using parentKode of the kecamatan
      final parentWilayah = _wilayah?.wilayah.data.firstWhereOrNull(
        (w) => w.kode == currentWilayah.parentKode,
      );
      kabupaten = parentWilayah?.nama ?? '';

      if (parentWilayah != null) {
        // 3. Find the provinsi using parentKode of the kabupaten
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
                  _popupLayerController.hideAllPopups();
                  showDetailPanel(data);
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

    // Prepare primitive list maps to pass down safely across Isolate borders
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
      // Offload string matching and calculations down to your Isolate thread
      final List<MarkerConfig> computedConfigs = await Isolate.run(
        () => _generateMarkerConfigsIsolate({
          'filteredPekerjaan': securePayloadList,
          'baseDir': baseDir,
        }),
      );

      // Map configuration rules directly into real elements on Main UI Thread safely
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

  /// Reset or Clear variables (e.g. on logout or filter wipe)
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