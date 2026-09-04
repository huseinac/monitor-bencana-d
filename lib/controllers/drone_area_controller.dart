import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../models/drone_area_model.dart';

List<DroneAreaModel> _parseDroneAreaIsolate(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    throw Exception("File not found at $filePath");
  }
  final jsonString = file.readAsStringSync();
  return droneAreaModelFromJson(jsonString);
}

class DroneAreaController extends ChangeNotifier {
  List<DroneAreaModel> _data = [];
  int? _selectedKabkotaId;

  bool _isLoading = false;
  bool _isLoaded = false;
  String? _error;

  List<DroneAreaModel> get data => _data;
  int? get selectedKabkotaId => _selectedKabkotaId;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  String? get error => _error;
  bool get hasData => _data.isNotEmpty;
  int get count => _data.length;

  DroneAreaController();

  void selectKabkota(int? id) {
    _selectedKabkotaId = id;
    notifyListeners();
  }

  Future<void> loadDroneAreaData({bool forceReload = false}) async {
    if (_isLoaded && !_isLoading && !forceReload) {
      debugPrint('Ringkasan Kab/Kota data already loaded, skipping...');
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
        '$userProfile\\AppData\\Roaming\\SatgasPRR\\monitor_bencana_d\\json_data\\kabkota.json';

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('Loading ringkasan kab/kota data from: $targetPath');

      final List<DroneAreaModel> result =
          await Isolate.run(() => _parseDroneAreaIsolate(targetPath));

      _data = result;
      _isLoaded = true;
    } catch (e) {
      _error = e.toString();
      _isLoaded = false;
      debugPrint("Error reading/parsing Ringkasan Kab/Kota JSON: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DroneAreaModel? getKabkotaById(int id) {
    try {
      return _data.firstWhere((item) => item.kabkotaId == id);
    } catch (_) {
      return null;
    }
  }

  void clearData() {
    _data = [];
    _selectedKabkotaId = null;
    _isLoaded = false;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}