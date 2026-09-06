import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/wilayah_selection_controller.dart';

import '../widgets/loading.dart';
import '../widgets/map_view.dart';
import '../widgets/wilayah_panel.dart';
import '../widgets/indikator_panel.dart';
import '../widgets/renduk_panel.dart';
import '../widgets/tkd_panel.dart';
import '../widgets/drone_panel.dart';
import '../widgets/combo_box_area.dart';
import '../widgets/pekerjaan_renduk_detail_panel.dart';

import '../controllers/indikator_controller.dart';
import '../controllers/paket_pekerjaan_controller.dart';
import '../controllers/pekerjaan_controller.dart';
import '../controllers/status_anggaran_controller.dart';
import '../controllers/status_pelaksanaan_controller.dart';
import '../controllers/kategori_paket_pekerjaan_controller.dart';
import '../controllers/drone_area_controller.dart';

import '../models/drone_area_detail_model.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => HomeViewState();
}

class HomeViewState extends State<HomeView> {
  final GlobalKey<MapViewState> mapView = GlobalKey<MapViewState>();
  final IndikatorController indikator = IndikatorController();

  late final PaketPekerjaanController paketPekerjaan =
      context.read<PaketPekerjaanController>();

  late final PekerjaanController pekerjaanController =
      context.read<PekerjaanController>();

  late final DroneAreaController droneArea =
      context.read<DroneAreaController>();

  int _mapStyle = 1;
  bool _isLoading = false;

  String _showMonitorButton = '';
  String _isShowPanel = '';
  String _sidebarActiveButton = '';

  @override
  void initState() {
    super.initState();
    showLoading(true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<WilayahSelectionController>().ensureDataLoaded();
      await context.read<IndikatorController>().loadIndikatorData();
      await context.read<PekerjaanController>().loadPekerjaanData();
      await context.read<StatusAnggaranController>().loadStatusAnggaranData();
      await context.read<StatusPelaksanaanController>().loadStatusPelaksanaanData();
      await context.read<KategoriPaketPekerjaanController>().loadKategoriPaketPekerjaanData();
      await context.read<DroneAreaController>().loadDroneAreaData();
      _periksaDataOfflinePadaStartup();
    });
    showLoading(false);
  }

  void showLoading(bool state) {
    setState(() => _isLoading = state);
  }

  void _periksaDataOfflinePadaStartup() {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null) return;

    // Sesuaikan dengan path folder monitor_bencana_d Anda
    final String pathFolder = '$userProfile\\AppData\\Roaming\\SatgasPRR\\monitor_bencana_d\\';
    final String normalizedPath = pathFolder
        .replaceAll('/', Platform.pathSeparator)
        .replaceAll('\\', Platform.pathSeparator);

    final folderData = Directory(normalizedPath);

    // Cek apakah foldernya ada, atau apakah di dalamnya kosong
    if (!folderData.existsSync() || folderData.listSync().isEmpty) {
      // Selalu pastikan widget masih aktif sebelum memanggil ScaffoldMessenger
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Data offline tidak ditemukan, mohon untuk unduh data terlebih dahulu!',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating, // Membuat tampilan snackbar melayang lebih modern
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  void _setShowPanel(String value) {
    setState(() {
      _isShowPanel = value;
    });
    pekerjaanController.setMarkersVisible(value == 'pekerjaan');
  }

  void _rightPanelToggle() {
    if (_isShowPanel.isNotEmpty) {
      _setShowPanel('');
    } else {
      _setShowPanel(_showMonitorButton);
    }
  }

  Future<void> _downloadAllJson() async {
    setState(() => _isLoading = true);
    
    //final List<String> endpoints = [
    //  'https://geopas.satgasprr.go.id/map/get_anggaran',
    //  'https://geopas.satgasprr.go.id/map/get_indikator',
    //  'https://geopas.satgasprr.go.id/map/get_pekerjaan',
    //  'https://geopas.satgasprr.go.id/map/get_wilayah_all',
    //  'https://geopas.satgasprr.go.id/map/get_status_pelaksanaan',
    //  'https://geopas.satgasprr.go.id/map/get_pelaksana',
    //  'https://geopas.satgasprr.go.id/map/get_status_anggaran',
    //  'https://geopas.satgasprr.go.id/home/kabkota',
    //];

    try {
      final Directory appDataDir = await getApplicationSupportDirectory();
      
      //for (String url in endpoints) {
      //  final response = await http.get(Uri.parse(url));
      //  if (response.statusCode == 200) {
      //    final String fileName = _getCleanFileName(url);
      //    final File file = File('${appDataDir.path}/json_data/$fileName.json');
          
      //    await file.parent.create(recursive: true);
      //    await file.writeAsString(response.body);
      //  }
      //}

      //final String zipUrl = 'https://geopas.satgasprr.go.id/download_asset';
      //final zipResponse = await http.get(Uri.parse(zipUrl));

      //if (zipResponse.statusCode == 200) {
      //  final Archive archive = ZipDecoder().decodeBytes(zipResponse.bodyBytes);

      //  for (final ArchiveFile file in archive) {
      //    final String filename = file.name;
          
      //    final String localPath = '${appDataDir.path}/$filename';
      //    final File outFile = File(localPath);

      //    if (file.isFile) {
      //      await outFile.parent.create(recursive: true);
      //      await outFile.writeAsBytes(file.content as List<int>);
      //    } else {
      //      await Directory(localPath).create(recursive: true);
      //    }
      //  }
      //} else {
      //  throw Exception('Server returned code ${zipResponse.statusCode} for assets package zip.');
      //}

      //int x = droneArea.count;

      //if (x < 1) {
      //  await droneArea.loadDroneAreaData();
      //}

      for (final da in droneArea.data) {
        final String droneVidUri = "https://geopas.satgasprr.go.id/home/kabkota/${da.kabkotaId}/drone";

        try {
          final dronedataresponse = await http.get(Uri.parse(droneVidUri));
          if (dronedataresponse.statusCode != 200) continue;

          final decoded = jsonDecode(dronedataresponse.body);
          if (decoded is! List || decoded.isEmpty) continue;

          final Map<String, dynamic> firstItem = decoded.first as Map<String, dynamic>;
          if (firstItem['views'] is! List) continue;

          final List<dynamic> views = firstItem['views'] as List<dynamic>;

          for (final xx in views) {
            if (xx is Map<String, dynamic> &&
                xx['videos'] is List &&
                (xx['videos'] as List).isNotEmpty) {
              
              final String? videoUrlStr = xx['videos'][0]['url']?.toString();
              if (videoUrlStr == null || videoUrlStr.isEmpty) continue;

              final Uri videoUri = Uri.parse(videoUrlStr);
              final String vidFileName = videoUri.pathSegments.last;
              final File vidFile = File('${appDataDir.path}/droneVideo/$vidFileName');

              await vidFile.parent.create(recursive: true);

              final response = await http.get(videoUri);
              if (response.statusCode == 200) {
                await vidFile.writeAsBytes(response.bodyBytes);
              } else {
                debugPrint('Failed video HTTP status ${response.statusCode} for $videoUrlStr');
              }
            }
          }
        } catch (e) {
          debugPrint("Error processing drone videos for KabKota ${da.kabkotaId}: $e");
        }
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

  String _getCleanFileName(String urlString) {
    final Uri uri = Uri.parse(urlString);
    return uri.pathSegments.last; 
  }

  Future<void> _navMenuEvent(String context) async {
    showLoading(true);

    await Future.delayed(Duration.zero);
    setState(() {
      _showMonitorButton = context;
      _mapStyle = context == 'pekerjaan' ? 2 : 1;
      _sidebarActiveButton = context;
    });
    _setShowPanel('');

    switch (context) {
      case "update":
        await paketPekerjaan.loadPaketData(forceReload: true);
        await paketPekerjaan.generateMarkers();
        paketPekerjaan.setMarkersVisible(true);
        break;
      case "pekerjaan":
        pekerjaanController.clearFilters();
        await pekerjaanController.loadPekerjaanData(forceReload: true);
        pekerjaanController.setMarkersVisible(true);
        paketPekerjaan.setMarkersVisible(false);
      break;
      case "drone":
        _setShowPanel(_showMonitorButton);
      break;
      default:
        paketPekerjaan.setMarkersVisible(false);
    }
    showLoading(false);
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
                child: Image.asset('assets/icons/logo.png', height: 42),
              ),
            ),
            Image.asset('assets/icons/logo2.png', height: 42),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: MapView(
              key: mapView,
              mapStyle: _mapStyle,
              showLoading: showLoading,
            ),
          ),

          Positioned(
            bottom: 50,
            right: 70,
            child: FloatingActionButton.extended(
              onPressed: _downloadAllJson,
              label: const Text("Unduh data"),
              icon: const Icon(Icons.download),
              backgroundColor: Color(0xFF22467a),
              foregroundColor: Colors.white,
            ),
          ),

          // Main Navigation Sidebar
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: SizedBox(
              width: 150,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSidebarButton(
                    imagePath: 'assets/icons/wilayah.png',
                    label: "Wilayah",
                    bgColor: _sidebarActiveButton == 'wilayah' ? Color(0xFF22467a) : Colors.white,
                    textColor: _sidebarActiveButton == 'wilayah' ? Colors.white : Colors.black,
                    onTap: () => _navMenuEvent('wilayah'),
                  ),
                  const SizedBox(height: 16),
                  _buildSidebarButton(
                    imagePath: 'assets/icons/indikator.png',
                    label: "Update kondisi (Indikator)",
                    bgColor: _sidebarActiveButton == 'update' ? Color(0xFF22467a) : Colors.white,
                    textColor: _sidebarActiveButton == 'update' ? Colors.white : Colors.black,
                    onTap: () => _navMenuEvent('update'),
                  ),
                  const SizedBox(height: 16),
                  _buildSidebarButton(
                    imagePath: 'assets/icons/pekerjaan.png',
                    label: "DalRenduk",
                    bgColor: _sidebarActiveButton == 'pekerjaan' ? Color(0xFF22467a) : Colors.white,
                    textColor: _sidebarActiveButton == 'pekerjaan' ? Colors.white : Colors.black,
                    onTap: () => _navMenuEvent('pekerjaan'),
                  ),
                  const SizedBox(height: 16),
                  _buildSidebarButton(
                    imagePath: 'assets/icons/tkd.png',
                    label: "TKD",
                    bgColor: _sidebarActiveButton == 'tkd' ? Color(0xFF22467a) : Colors.white,
                    textColor: _sidebarActiveButton == 'tkd' ? Colors.white : Colors.black,
                    onTap: () => _navMenuEvent('tkd'),
                  ),
                  const SizedBox(height: 16),
                  _buildSidebarButton(
                    imagePath: 'assets/icons/videodrone.png',
                    label: "Video Drone",
                    bgColor: _sidebarActiveButton == 'drone' ? Color(0xFF22467a) : Colors.white,
                    textColor: _sidebarActiveButton == 'drone' ? Colors.white : Colors.black,
                    onTap: () => _navMenuEvent('drone'),
                  ),
                ],
              ),
            ),
          ),

          // Small Right Toggle Button (like original)
          if (_showMonitorButton.isNotEmpty && _showMonitorButton != 'drone')
            Positioned(
              top: 10,
              right: 40,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _rightPanelToggle(),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.5)),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/icons/database_${_showMonitorButton == 'wilayah' ? 'wilayah' : _showMonitorButton == 'update' ? 'indikator' : _showMonitorButton == 'pekerjaan' ? 'pekerjaan' : 'tkd'}.png',
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Wilayah Panel
          Positioned(
            top: 10,
            right: 40,
            child: Visibility(
              visible: _isShowPanel == 'wilayah',
              maintainState: true,
              maintainAnimation: true,
              maintainSize: false,
              child: WilayahPanel(
                onClose: () => _setShowPanel(""),
                mapViewKey: mapView,
              ),
            ),
          ),

          Positioned(
            top: 10,
            right: 40,
            child: Visibility(
              visible: _isShowPanel == 'update',
              maintainState: true,
              maintainAnimation: true,
              maintainSize: false,
              child: IndikatorPanel(
                onClose: () => _setShowPanel(""),
                mapViewKey: mapView,
              ),
            ),
          ),

          Positioned(
            top: 10,
            bottom: 10,
            right: 40,
            child: Visibility(
              visible: _isShowPanel == 'pekerjaan',
              maintainState: true,
              maintainAnimation: true,
              maintainSize: false,
              child: RendukPanel(
                onClose: () => _setShowPanel(""),
              ),
            ),
          ),

          Positioned(
            top: 10,
            right: 40,
            bottom: 10,
            child: Visibility(
              visible: _isShowPanel == 'tkd',
              maintainState: true,
              maintainAnimation: true,
              maintainSize: false,
              child: TkdPanel(
                onClose: () => _setShowPanel(""),
              ),
            ),
          ),

          Positioned(
            top: 10,
            right: 40,
            bottom: 10,
            child: Visibility(
              visible: _isShowPanel == 'drone',
              maintainState: true,
              maintainAnimation: true,
              maintainSize: false,
              child: DronePanel(
                onClose: () => _setShowPanel(""),
              ),
            ),
          ),

          if (_isLoading) Loading(),

          if (mapView.currentState?.currentMapLevel != null &&
              mapView.currentState!.currentMapLevel > 1)
            Positioned(
              top: 60,
              left: 100,
              child: FloatingActionButton.extended(
                onPressed: () {
                  showLoading(true);
                  mapView.currentState?.mapNavBack();
                  showLoading(false);
                },
                label: const Text("Kembali"),
                icon: const Icon(Icons.arrow_back),
                backgroundColor: Color(0xFF22467a),
                foregroundColor: Colors.white,
              ),
            ),

          Positioned(
            top: 10,
            right: 40,
            child: Consumer<PekerjaanController>(
              builder: (context, controller, _) {
                if (!controller.isDetailPanelVisible) return const SizedBox.shrink();
                return const PekerjaanRendukDetailPanel();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarButton({
    required String imagePath,
    required String label,
    required Color bgColor,
    required Color textColor,
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
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(imagePath, width: 30, height: 30, fit: BoxFit.contain),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}