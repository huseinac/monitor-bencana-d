import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:latlong2/latlong.dart';
import 'package:monitor_bencana_d/models/indikator_model.dart';
import '../models/paket_pekerjaan_model.dart';

import '../controllers/wilayah_selection_controller.dart';
import '../controllers/indikator_controller.dart';

/// Top-level function to parse JSON safely in a background Isolate
List<PaketPekerjaanModel> _parsePaketPekerjaanIsolate(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    throw Exception("Data file not found at: $filePath");
  }
  
  final jsonString = file.readAsStringSync();
  final Map<String, dynamic> decodedJson = jsonDecode(jsonString);
  
  final List<PaketPekerjaanModel> extractedPaket = [];
  
  if (decodedJson.containsKey('list_indikator')) {
    final listIndikator = decodedJson['list_indikator'] as List<dynamic>;
    
    for (var indikator in listIndikator) {
      if (indikator is Map<String, dynamic> && indikator.containsKey('list_sektor_terdampak')) {
        final listSektor = indikator['list_sektor_terdampak'] as List<dynamic>?;
        if (listSektor != null) {
          for (var sektor in listSektor) {
            if (sektor is Map<String, dynamic>) {
              extractedPaket.add(PaketPekerjaanModel.fromJson(sektor));
            }
          }
        }
      }
    }
  }
  
  return extractedPaket;
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

/// Top-level function processing marker path strings inside an Isolate.
List<MarkerConfig> _generateMarkerConfigsIsolate(Map<String, dynamic> params) {
  final List<dynamic> rawFiltered = params['filteredPekerjaan'];
  final String baseDir = params['baseDir'];

  final List<MarkerConfig> configs = [];

  for (var raw in rawFiltered) {
    // Reconstruct small internal maps from isolate payload safely
    final double? lat = raw['latitude'];
    final double? lng = raw['longitude'];
    final int? progress = raw['persentase'];
    final int indId = raw['indikatorId'] ?? 0;
    final String indicatorName = raw['namaLokasi'] ?? '-';
    final int id = raw['id'];

    if (lat == null || lng == null || progress == null) continue;

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

    final String imageRelativePath = 'assets/icons/$markerImage';
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

class PaketPekerjaanController extends ChangeNotifier {
  final PopupController _popupLayerController = PopupController();
  PopupController get popupLayerController => _popupLayerController;

  WilayahSelectionController? _wilayah;

  List<PaketPekerjaanModel> _allPaket = [];
  PaketPekerjaanModel? _selectedPaket;
  List<PaketPekerjaanModel> _filteredPekerjaan = [];
  List<PaketPekerjaanModel> get filteredPaket => _filteredPekerjaan;

  List<Marker> _markers = [];
  bool _markersVisible = false;

  List<Marker> get markers => _markersVisible ? _markers : [];
  
  // States
  bool _isLoading = false;
  bool _isLoaded = false;
  String? _error;

  // Getters
  List<PaketPekerjaanModel> get allPaket => _allPaket;
  PaketPekerjaanModel? get selectedPaket => _selectedPaket;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  String? get error => _error;
  int get totalCount => _allPaket.length;

  String? _filterKeyword;

  PaketPekerjaanController();

  void setMarkersVisible(bool visible) {
    if (_markersVisible == visible) return;
    _markersVisible = visible;
    notifyListeners();
  }

  Future<void> filterByIndikatorId(int? indikatorId) async {
    _filteredPekerjaan = indikatorId == null
        ? _allPaket
        : _allPaket.where((p) => p.indikatorId == indikatorId).toList();

    await generateMarkers();
  }

  void filterByKeyword(String? keyword) {
    _filterKeyword = (keyword == null || keyword.trim().isEmpty) ? null : keyword.trim();
    _applyFilters();
  }

  void clearFilters() {
    _filterKeyword = null;
    _applyFilters();
  }

  Future<void> _applyFilters() async {
    Iterable<PaketPekerjaanModel> result = _allPaket;

    if (_filterKeyword != null) {
      final lowerKeyword = _filterKeyword!.toLowerCase();
      result = result.where(
        (p) => (p.namaLokasi ?? '').toLowerCase().contains(lowerKeyword),
      );
    }

    if(_wilayah?.activeAreaCode != '0') {
      result = result.where((p) {
        final activeCode = _wilayah?.activeAreaCode;

        // 1. If 'All' is chosen or there's no active filter, let all items pass through
        if (activeCode == null || activeCode == '0' || activeCode.isEmpty) {
          return true;
        }

        // 2. Safely find the matching wilayah entry using .id
        final matchingWilayah = _wilayah?.wilayah.data.firstWhereOrNull(
          (w) => w.id == p.wilayahId,
        );

        // 3. Use startsWith to match hierarchical area codes correctly
        final kode = matchingWilayah?.kode;
        return kode != null && kode.startsWith(activeCode);
      });
    }

    _filteredPekerjaan = result.toList();
    await generateMarkers();
  }

  void updateWilayahSelection(WilayahSelectionController wilayahSelection) {
    _wilayah = wilayahSelection;
  }

  /// Loads the flat list of Paket Pekerjaan from the Windows local JSON file
  Future<void> loadPaketData({bool forceReload = false}) async {
    if (_isLoaded && !_isLoading && !forceReload) {
      debugPrint('Paket Pekerjaan already loaded, skipping...');
      return;
    }

    if (!Platform.isWindows) {
      throw UnsupportedError("This file path resolution is specific to Windows.");
    }

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null) {
      throw Exception("Could not find USERPROFILE environment variable.");
    }

    final String targetPath =
        '$userProfile\\AppData\\Roaming\\SatgasPRR\\monitor_bencana_d\\json_data\\get_indikator.json';

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('Loading Paket Pekerjaan from: $targetPath');
      
      // Offload heavy JSON parsing to an Isolate to prevent UI frame drops
      final List<PaketPekerjaanModel> result = 
          await Isolate.run(() => _parsePaketPekerjaanIsolate(targetPath));
      
      _allPaket = result;

      _filteredPekerjaan = result;
      await _applyFilters();
      _isLoaded = true;
    } catch (e) {
      _error = e.toString();
      _isLoaded = false;
      debugPrint("Error reading/parsing JSON: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  PaketPekerjaanModel? getPekerjaanById(int id) {
    try {
      return allPaket.firstWhere((pekerjaan) => pekerjaan.id == id);
    } catch (_) {
      return null;
    }
  }

  //void generateMarkers() {
  //  final userProfile = Platform.environment['USERPROFILE'];
  //  if (userProfile == null) return;
    
  //  // 1. Resolve path once globally instead of inside the loop
  //  final String baseDir = '$userProfile\\AppData\\Roaming\\SatgasPRR\\monitor_bencana_d\\'
  //      .replaceAll('/', Platform.pathSeparator)
  //      .replaceAll('\\', Platform.pathSeparator);

  //  final List<Marker> compiledMarkers = [];

  //  for (var pekerjaan in _filteredPekerjaan) {
  //    // 2. Quick double checks from model fields
  //    if (pekerjaan.latitude == null || pekerjaan.longitude == null) continue;
  //    if (pekerjaan.persentase == null) continue; 

  //    // 3. Directly calculate icon name strings purely through logic mapping
  //    final String indicatorName = pekerjaan.namaLokasi ?? '-';
  //    String markerImage = 'help'; 
  //    final int indId = pekerjaan.indikatorId;

  //    if (indId == 2 || indId == 3 || indId == 4 || indId == 5 || indId == 34) {
  //      markerImage = 'building';
  //    } else if (indId == 8 || indId == 10 || indId == 11 || indId == 12) {
  //      markerImage = 'health';
  //    } else if (indId == 13 || indId == 14 || indId == 16 || indId == 17 || indId == 18 || indId == 19) {
  //      markerImage = 'school';
  //    } else if (indId == 21 || indId == 22 || indId == 24 || indId == 25 || indId == 26) {
  //      markerImage = 'road';
  //    } else if (indicatorName.contains('Jembatan')) {
  //      markerImage = 'bride'; 
  //    } else if (indId == 37) {
  //      markerImage = 'electric';
  //    } else if (indId == 38) {
  //      markerImage = 'water';
  //    } else if (indId == 35) {
  //      markerImage = 'religion';
  //    } else if (indId == 41 || indId == 43) {
  //      markerImage = 'river';
  //    } else if (['Huntara', 'Huntap'].any(indicatorName.contains)) {
  //      markerImage = 'home';
  //    } else if (indId == 44 || indId == 45 || indId == 46) {
  //      markerImage = 'homes';
  //    } else if (indId == 36) {
  //      markerImage = 'gas_station';
  //    } else if (indId == 40) {
  //      markerImage = 'gas';
  //    } else if (indId == 27 || indId == 31 || indId == 32 || indId == 48) {
  //      markerImage = 'store';
  //    }

  //    // Progress color matching logic
  //    final int progress = pekerjaan.persentase!;
  //    if (progress <= 40) {
  //      markerImage += '-yellow';
  //    } else if (progress > 40 && progress <= 70) {
  //      markerImage += '-blue';
  //    } else if (progress > 70 && progress <= 100) {
  //      markerImage += '-green';
  //    } else {
  //      markerImage += '-red';
  //    }
  //    markerImage += '.png';

  //    // 4. PRE-COMPUTE target local structural file path string purely in memory
  //    final String imageRelativePath = 'assets/icons/$markerImage';
  //    final String fullLocalPath = '$baseDir$imageRelativePath';

  //    compiledMarkers.add(
  //      Marker(
  //        key: ValueKey(pekerjaan.id),
  //        point: LatLng(pekerjaan.latitude!, pekerjaan.longitude!),
  //        width: 32,
  //        height: 32,
  //        child: RepaintBoundary(
  //          child: Container(
  //            padding: const EdgeInsets.all(4),
  //            decoration: BoxDecoration(
  //              color: const Color(0xFF1A1A1A),
  //              shape: BoxShape.circle,
  //              border: Border.all(color: Colors.white, width: 2.0),
  //              boxShadow: const [
  //                BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))
  //              ],
  //            ),
  //            child: AppImage(
  //              // Directly pass full computed path without checking File(x).existsSync()
  //              fullLocalPath,
  //              fit: BoxFit.contain,
  //              errorBuilder: (context, error, stackTrace) => const Icon(
  //                Icons.location_on, 
  //                color: Colors.red, 
  //                size: 24,
  //              ),
  //            ),
  //          ),
  //        ),
  //      ),
  //    );
  //  }

  //  _markers = compiledMarkers;
  //  notifyListeners();
  //}

  Future<void> generateMarkers() async {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null) return;

    final String baseDir = '$userProfile\\AppData\\Roaming\\SatgasPRR\\monitor_bencana_d\\'
        .replaceAll('/', Platform.pathSeparator)
        .replaceAll('\\', Platform.pathSeparator);

    // Prepare primitive list maps to pass down safely across Isolate borders
    final List<Map<String, dynamic>> securePayloadList = _filteredPekerjaan
        .map((p) => {
              'id': p.id,
              'latitude': p.latitude,
              'longitude': p.longitude,
              'persentase': p.persentase,
              'indikatorId': p.indikatorId,
              'namaLokasi': p.namaLokasi,
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
      // Map configuration rules directly into real elements on Main UI Thread safely
      _markers = computedConfigs.map((config) {
        return Marker(
          key: ValueKey(config.id),
          point: LatLng(config.latitude, config.longitude),
          width: 28,  // Slightly smaller markers consume significantly lower pixel fill-rate
          height: 28, // profiles on high-density map displays
          child: MapMarkerWidget(imagePath: config.fullLocalPath),
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint("Error generating markers in background isolate: $e");
    }
  }

  Widget buildPopupForMarker(BuildContext context, Marker marker) {
    final id = (marker.key as ValueKey).value as int;
    final pekerjaan = getPekerjaanById(id);
    if (pekerjaan == null) return const SizedBox.shrink();

    final indikatorObj = Provider.of<IndikatorController>(context, listen: false);
    return _buildIndikatorPopup(pekerjaan, context, indikatorController: indikatorObj);
  }

  Widget _buildIndikatorPopup(PaketPekerjaanModel pekerjaan, BuildContext context, {required IndikatorController indikatorController}) {
    String nama = pekerjaan.namaLokasi ?? 'Tanpa Nama';
    
    final currentWilayah = _wilayah?.wilayah.data.firstWhereOrNull(
      (w) => w.id == pekerjaan.wilayahId,
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

    // 4. Combine them cleanly (filtering out empty values if any lookups failed)
    String wilayahInfo = [provinsi, kabupaten, kecamatan]
        .where((str) => str.isNotEmpty)
        .join(' - ');
    ;
    String kondisi = pekerjaan.kondisi ?? '-';

    final indikatornya = indikatorController.data.firstWhereOrNull(
      (ind) => ind.id == pekerjaan.indikatorId,
    );

    String indikatorNama = indikatornya?.nama ?? '-';

    String status = pekerjaan.status ?? '-';
    String kondisiAwal = pekerjaan.kondisiAwal ?? '-';
    String keterangan = pekerjaan.keterangan ?? '-';

    int persentasePulih = pekerjaan.persentase ?? 0;
    //var rawPersentase = sektor['persentase'];
    //if (rawPersentase != null) {
    //  persentasePulih = double.tryParse(rawPersentase.toString()) ?? 0.0;
    //}

    String markerImage = '';
    if (indikatorNama.contains('Kantor')) {
        markerImage = 'building';
    } else if (indikatorNama.contains('Faskes')) {
        markerImage = 'health';
    } else if (
        indikatorNama.contains('PAUD') ||
        indikatorNama.contains('TK') ||
        indikatorNama.contains('SD') ||
        indikatorNama.contains('SMP') ||
        indikatorNama.contains('SMA/SMK') ||
        indikatorNama.contains('Madrasah/Ponpes')
      ) {
        markerImage = 'school';
    } else if (indikatorNama.contains('Jalan')) {
        markerImage = 'road';
    } else if (indikatorNama.contains('Jembatan')) {
        markerImage = 'bride';
    } else if (indikatorNama.contains('Kelistrikan')) {
        markerImage = 'electric';
    } else if (indikatorNama.contains('PDAM/SPAM')) {
        markerImage = 'water';
    } else if (indikatorNama.contains('Gedung Rumah Ibadah')) {
        markerImage = 'religion';
    } else if (indikatorNama.contains('Sungai')) {
        markerImage = 'river';
    } else if (
        indikatorNama.contains('Huntara') ||
        indikatorNama.contains('Huntap')
      ) {
        markerImage = 'home';
    } else if (indikatorNama.contains('Pengungsian')) {
        markerImage = 'homes';
    } else if (
        indikatorNama.contains('toko diluar pasar') ||
        indikatorNama.contains('Hotel/Penginapan')
      ) {
        markerImage = 'building';
    } else if (indikatorNama.contains('SPBU')) {
        markerImage = 'gas_station';
    } else if (indikatorNama.contains('Gas LPG')) {
        markerImage = 'gas';
    } else if (
        indikatorNama.contains('Gedung/Sarpras Pasar') ||
        indikatorNama.contains('Gedung/Sarpras Resto/Warung/Kafe/kedai') ||
        indikatorNama.contains('Koperasi')
      ) {
        markerImage = 'store';
    } else if (indikatorNama.contains('INTERNET')) {
        markerImage = 'help';
    } else if (
        indikatorNama.contains('Persawahan') ||
        indikatorNama.contains('Perikanan (Tambak)')
      ) {
        markerImage = 'river';
    } else if (
        indikatorNama.contains('Pembersihan lumpur') ||
        indikatorNama.contains('DTH')
      ) {
        markerImage = 'help';
    }

    switch (pekerjaan.status) {
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

    //_getAssetPath('assets/sektor_terdampak/${pekerjaan.fotoSebelum}')
    final String? sebelumPath = pekerjaan.fotoSebelum == null ? null : 
      (Platform.environment['USERPROFILE'] ?? '') + '\\AppData\\Roaming\\SatgasPRR\\monitor_bencana_d\\assets\\${(pekerjaan.fotoSebelum?.replaceAll('/', Platform.pathSeparator))}'
    ;
    final String? sesudahPath = pekerjaan.fotoSesudah == null ? null : 
      (Platform.environment['USERPROFILE'] ?? '') + '\\AppData\\Roaming\\SatgasPRR\\monitor_bencana_d\\assets\\${(pekerjaan.fotoSesudah?.replaceAll('/', Platform.pathSeparator))}'
    ;
    //final String? sesudahPath = pekerjaan.fotoSesudah == null ? null : _getAssetPath('assets/sektor_terdampak/${pekerjaan.fotoSesudah}');

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
      child:Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama.toUpperCase(),
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
                      "${pekerjaan.persentase}%",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (persentasePulih.toDouble() / 100),
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
                          indikatorNama,
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
                                  message: "Foto sebelum. Klik untuk memperbesar",
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
                            : const Text("Tidak ada foto sebelum", style: TextStyle(color: Colors.white38, fontSize: 12)),
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
                                    message: "Foto sesudah. Klik untuk memperbesar",
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
                              : const Text("Tidak ada foto sesudah", style: TextStyle(color: Colors.white38, fontSize: 12)),
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
                //_buildMetaRow("Wilayah", "wilayahInfo"),
                //_buildMetaRow("Kondisi", "kondisi"),
                //_buildMetaRow("Status", "status"),
                //_buildMetaRow("Kondisi Awal", "kondisiAwal"),
                //_buildMetaRow("Keterangan", "keterangan"),
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
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
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

  // ==========================================
  // DATA SELECTION METHODS
  // ==========================================

  /// Selects a specific Paket Pekerjaan item directly
  void selectPaket(PaketPekerjaanModel? paket) {
    _selectedPaket = paket;
    notifyListeners();
  }

  /// Finds and selects a Paket Pekerjaan item by its ID
  void selectPaketById(int id) {
    try {
      _selectedPaket = _allPaket.firstWhere((paket) => paket.id == id);
    } catch (_) {
      _selectedPaket = null;
    }
    notifyListeners();
  }

  /// Clears the current active selection
  void clearSelection() {
    _selectedPaket = null;
    notifyListeners();
  }

  /// Resets the controller state completely
  void reset() {
    _allPaket = [];
    _selectedPaket = null;
    _isLoaded = false;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}