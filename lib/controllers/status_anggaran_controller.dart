import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../models/status_anggaran_model.dart';

List<StatusAnggaranModel> _parseStatusAnggaranIsolate(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    throw Exception("File not found at $filePath");
  }
  final jsonString = file.readAsStringSync();
  return statusAnggaranModelFromJson(jsonString);
}

class StatusAnggaranController extends ChangeNotifier {
  List<StatusAnggaranModel> _data = [];
  int? _selectedStatusId;


  bool _isLoading = false;
  bool _isLoaded = false;
  String? _error;


  List<StatusAnggaranModel> get data => _data;
  int? get selectedStatusId => _selectedStatusId;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  String? get error => _error;
  bool get hasData => _data.isNotEmpty;
  int get count => _data.length;

  StatusAnggaranController();


  void selectStatus(int? id) {
    _selectedStatusId = id;
    notifyListeners();
  }


  Future<void> loadStatusAnggaranData({bool forceReload = false}) async {
    if (_isLoaded && !_isLoading && !forceReload) {
      debugPrint('Status Anggaran data already loaded, skipping...');
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
        '$userProfile\\AppData\\Roaming\\SatgasPRR\\monitor_bencana_d\\json_data\\get_status_anggaran.json';

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('Loading status anggaran data from: $targetPath');

      final List<StatusAnggaranModel> result =
          await Isolate.run(() => _parseStatusAnggaranIsolate(targetPath));

      _data = result;
      _isLoaded = true;
    } catch (e) {
      _error = e.toString();
      _isLoaded = false;
      debugPrint("Error reading/parsing Status Anggaran JSON: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  StatusAnggaranModel? getStatusById(int id) {
    try {
      return _data.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  void clearData() {
    _data = [];
    _selectedStatusId = null;
    _isLoaded = false;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}