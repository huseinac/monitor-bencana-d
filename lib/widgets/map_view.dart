import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:collection/collection.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

//Data Wilayah
import '../models/wilayah_model.dart';
import '../controllers/wilayah_controller.dart';
import '../controllers/wilayah_selection_controller.dart';
import '../controllers/paket_pekerjaan_controller.dart';
import '../controllers/pekerjaan_controller.dart';

import '../helper/clickable_polygon.dart';

Color _getColor(String kondisi, bool isFill, bool isHovered) {
  double op = isFill ? (isHovered ? 0.75 : 0.4) : (isHovered ? 1.0 : 0.8);
  switch (kondisi) {
    case 'Normal':
      return const Color(0xFF00A042).withOpacity(op);
    case 'Atensi':
      return const Color(0xFF998000).withOpacity(op);
    case 'Mendekati':
      return const Color(0xFF0030B3).withOpacity(op);
    case 'Provinsi':
      return Colors.white.withOpacity(isHovered ? 0.5 : 0.3);
    default:
      return isFill ? Color(0xFF00A042).withOpacity(op) : Color(0xFF00A042).withOpacity(op);
  }
}

class _NavSnapshot {
  final int level;
  final String activeAreaCode;
  final String selectedProv;
  final String selectedKabupaten;
  final String selectedKecamatan;
  final double zoom;
  final LatLng center;
  final List<ClickablePolygon> areaPolygons;
  final List<Marker> areaMarker;
  final Map<String, String> optionKabupaten;
  final Map<String, String> optionKecamatan;

  _NavSnapshot({
    required this.level,
    required this.activeAreaCode,
    required this.selectedProv,
    required this.selectedKabupaten,
    required this.selectedKecamatan,
    required this.zoom,
    required this.center,
    required this.areaPolygons,
    required this.areaMarker,
    required this.optionKabupaten,
    required this.optionKecamatan,
  });
}

class MapView extends StatefulWidget {
  final int mapStyle;
  final ValueChanged<bool> showLoading;

  const MapView({
    super.key,
    required this.mapStyle,
    required this.showLoading,
  });

  @override
  State<MapView> createState() => MapViewState();
}

class MapViewState extends State<MapView> {
  final MapController _mapController = MapController();

  DateTime _lastHoverCheck = DateTime.now();

  List<ClickablePolygon> _areaPolygons = [];
  List<Marker> _areaMarker = [];
  String? _hoveredCode;
  double mapZoomLevel = 7.0;

  final List<_NavSnapshot> _navStack = [];

  late final WilayahSelectionController _selection =
      context.read<WilayahSelectionController>();

  // --- Tile cache setup ---
  HiveCacheStore? _cacheStore;
  bool _cacheReady = false;

  void _pushSnapshot() {
    _navStack.add(_NavSnapshot(
      level: _selection.currentLevel,
      activeAreaCode: _selection.activeAreaCode,
      selectedProv: _selection.selectedProv,
      selectedKabupaten: _selection.selectedKabupaten,
      selectedKecamatan: _selection.selectedKecamatan,
      zoom: mapZoomLevel,
      center: _mapController.camera.center,
      areaPolygons: List.of(_areaPolygons),
      areaMarker: List.of(_areaMarker),
      optionKabupaten: Map.of(_selection.optionKabupaten),
      optionKecamatan: Map.of(_selection.optionKecamatan),
    ));
  }

  Future<void> _initTileCache() async {
    final dir = await getTemporaryDirectory();
    final cacheStore = HiveCacheStore(
      dir.path,
      hiveBoxName: 'MapTilesCache',
    );
    if (!mounted) return;
    setState(() {
      _cacheStore = cacheStore;
      _cacheReady = true;
    });
  }
  // --- end tile cache setup ---

  /*Data Wilayah*/
  final WilayahController _controller = WilayahController();
  
  List<WilayahModel> _wilayahList = [];
  String? _errorMessage;


  int get currentMapLevel => _selection.currentLevel;
  Future<void> setMapLevel(int level) async {
    _selection.setLevel(level);
    setState(() {
    });
    await showProvinsi();
  }

  Future<void> resetToTopLevel() async {
    await showProvinsi();
    _mapController.move(const LatLng(1.500, 100.000), 7.0);
    setState(() => mapZoomLevel = 7.0);
    _selection.resetSelections();
  }

  Future<void> selectProvinceByCode(String code) async {
    widget.showLoading(true);
    _pushSnapshot();

    if (code == '0') {
      await resetToTopLevel();
      return;
    }

    if (_selection.currentLevel != 1) {
      await showProvinsi();
    }

    final cp = _areaPolygons.firstWhereOrNull((p) => p.code == code);

    _selection.setSelectedProv(code);
    _selection.populateOptionKabupaten();
    _selection.setActiveAreaCode(code);
    _selection.setLevel(2);

    setState(() => mapZoomLevel = 8.5);
    await showKabupaten(code);
    if (cp != null) {
      debugPrint(cp.center.toString());
      _mapController.move(cp.center, mapZoomLevel);
    }
    widget.showLoading(false);
  }

  Future<void> selectKabupatenByCode(String code) async {
    widget.showLoading(true);
    _pushSnapshot();

    if (code == '0') return;
    if (_selection.currentLevel >= 3) {
      _selection.setLevel(2);
      await showKabupaten(_selection.selectedProv);
    }

    final cp = _areaPolygons.firstWhereOrNull((p) => p.code == code);

    _selection.setSelectedKabupaten(code);
    _selection.populateOptionKecamatan();
    _selection.setActiveAreaCode(code);
    _selection.setLevel(3);

    setState(() => mapZoomLevel = 9.5);
    await showKabupaten(code);
    if (cp != null) {
      _mapController.move(cp.center, mapZoomLevel);
    }
    widget.showLoading(false);
  }

  Future<void> selectKecamatanByCode(String code) async {
    widget.showLoading(true);
    _pushSnapshot();

    if (code == '0') return;
    if (_selection.currentLevel >= 4) {
      _selection.setLevel(3);
      await showKabupaten(_selection.selectedKabupaten);
    }

    final cp = _areaPolygons.firstWhereOrNull((p) => p.code == code);

    _selection.setSelectedKecamatan(code);
    _selection.setActiveAreaCode(code);
    _selection.setLevel(4); // explicit

    setState(() => mapZoomLevel = 12.0);
    await showKabupaten(code);
    if (cp != null) {
      _mapController.move(cp.center, mapZoomLevel);
    }
    widget.showLoading(false);
  }

  void mapNavBack() {
    widget.showLoading(true);
    if (_navStack.isEmpty) return; // already at the top, nothing to restore

    final snap = _navStack.removeLast();

    setState(() {
      mapZoomLevel = snap.zoom;
      _areaPolygons = snap.areaPolygons;
      _areaMarker = snap.areaMarker;
    });

    _selection.setLevel(snap.level);
    _selection.setActiveAreaCode(snap.activeAreaCode);
    _selection.setSelectedProv(snap.selectedProv);
    _selection.setSelectedKabupaten(snap.selectedKabupaten);
    _selection.setSelectedKecamatan(snap.selectedKecamatan);
    // If you exposed setters for these maps on the controller, restore them too:
    // _selection.setOptionKabupaten(snap.optionKabupaten);
    // _selection.setOptionKecamatan(snap.optionKecamatan);

    _mapController.move(snap.center, snap.zoom);
    widget.showLoading(false);
  }

  Future<void> _loadDataWilayah() async {
    try {
      await _controller.loadWilayahData();
      showProvinsi();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }
  /*Data Wilayah*/

  /*Data provinsi*/
  Future<void> showProvinsi() async {
    widget.showLoading(true);
    setState(() {
      _areaPolygons = [];
      _areaMarker = [];
    });

    await _controller.selectProvinsi();

    setState(() {
      _areaPolygons = _controller.areaPolygons;
      _areaMarker = _controller.areaMarker;
    });
    widget.showLoading(false);
  }
  /*Data provinsi*/

  /*Data kabupaten*/
  Future<void> showKabupaten(String parentCode) async {
    widget.showLoading(true);
    setState(() {
      _areaPolygons = [];
      _areaMarker = [];
    });

    await _controller.selectKabupaten(parentCode);

    setState(() {
      _areaPolygons = _controller.areaPolygons;
      _areaMarker = _controller.areaMarker;
    });
    widget.showLoading(false);
    if (_controller.areaPolygons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data wilayah tidak ditemukan !'),
          backgroundColor: Color(0xFFED4337),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  /*Data kabupaten*/

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

  void _onAreaClicked(String code, LatLng center) {
    widget.showLoading(true);
    _pushSnapshot();

    double targetZoom; 
    switch (_selection.currentLevel) {
      case 2:
        targetZoom = 9.5;
      break;
      case 3:
        targetZoom = 10.5;
      break;
      case 4:
        targetZoom = 12;
      break;
      default:
        targetZoom = mapZoomLevel + 2;
    }
    setState(() {
      mapZoomLevel = targetZoom;      
    });

    _selection.setActiveAreaCode(code);

    final newLevel = _selection.currentLevel + 1;
    _selection.setLevel(newLevel);

    if (_selection.currentLevel >= 2) {
      showKabupaten(code);
      _mapController.move(center, mapZoomLevel);

      if (_selection.currentLevel == 2) {
        _selection.setSelectedProv(code);
        _selection.populateOptionKabupaten();
      } else if(_selection.currentLevel == 3) {
        _selection.setSelectedKabupaten(code);
        _selection.populateOptionKecamatan();
      } else if(_selection.currentLevel == 4) {
        _selection.setSelectedKecamatan(code);
      }
    } else {
      showProvinsi();
      _selection.setSelectedProv('0');
      _selection.setSelectedKabupaten('0');
      _selection.setSelectedKecamatan('0');
    }
  }

  //void handleMapTap(LatLng point) {
  //  for (int i = _areaPolygons.length - 1; i >= 0; i--) {
  //    final cp = _areaPolygons[i];
  //    if (_isPointInPolygon(point, cp.polygon.points)) {
  //      _onAreaClicked(cp.code, cp.center);
  //      return;
  //    }
  //  }
  //}

  void handleMapTap(LatLng point) {
    for (int i = _areaPolygons.length - 1; i >= 0; i--) {
      final cp = _areaPolygons[i];
      if (cp.contains(point)) {
        _onAreaClicked(cp.code, cp.center);
        return;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initTileCache(); 
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadDataWilayah();
    });
  }

  @override
  Widget build(BuildContext context) {
    final paketPekerjaanController = context.watch<PaketPekerjaanController>();
    final pekerjaanController = context.watch<PekerjaanController>();

    return MouseRegion(
      cursor: _hoveredCode != null
      ? SystemMouseCursors.click
      : SystemMouseCursors.basic,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(1.500, 100.000),
          initialZoom: 7.0,
          onTap: (tapPos, point) => handleMapTap(point),
          onPointerHover: (event, point) {
            final now = DateTime.now();
            // Throttle hover checks to ~60 FPS (16ms interval)
            if (now.difference(_lastHoverCheck).inMilliseconds < 16) return;
            _lastHoverCheck = now;

            String? hitCode;
            for (var cp in _areaPolygons) {
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
            urlTemplate: (widget.mapStyle == 1 ? 
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}' 
              : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}'
            ),
            userAgentPackageName: 'com.satgasprr.monitor_bencana_d',
            tileProvider: _cacheReady
                ? CachedTileProvider(
                    maxStale: const Duration(days: 30),
                    store: _cacheStore!,
                  )
                : NetworkTileProvider(),
          ),
          PolygonLayer(
            polygons: _areaPolygons.map((cp) {
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
          //MarkerLayer(
          //  markers: [
          //    ..._areaMarker,
          //    ...paketPekerjaanController.markers,
          //  ],
          //),
          MarkerLayer(
            markers: [
              ..._areaMarker,
              //...pekerjaanController.markers,
            ],
          ),
          PopupMarkerLayer(
            options: PopupMarkerLayerOptions(
              markers: paketPekerjaanController.markers,
              popupController: paketPekerjaanController.popupLayerController,
              markerTapBehavior: MarkerTapBehavior.togglePopupAndHideRest(), // no arg
              onPopupEvent: (event, selectedMarkers) {
              },
              popupDisplayOptions: PopupDisplayOptions(
                builder: (context, marker) =>
                    paketPekerjaanController.buildPopupForMarker(context, marker),
              ),
            ),
          ),
          PopupMarkerLayer(
            options: PopupMarkerLayerOptions(
              markers: pekerjaanController.markers,
              popupController: pekerjaanController.popupLayerController,
              markerTapBehavior: MarkerTapBehavior.togglePopupAndHideRest(), // no arg
              onPopupEvent: (event, selectedMarkers) {
              },
              popupDisplayOptions: PopupDisplayOptions(
                builder: (context, marker) =>
                    pekerjaanController.buildPopupForMarker(context, marker),
              ),
            ),
          ),
        ],
      ),
    );
  }
}