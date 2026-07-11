import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../models/indikator_model.dart';
import '../controllers/paket_pekerjaan_controller.dart'; // Verified import

IndikatorResponse _parseJsonIsolate(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    throw Exception("File not found at $filePath");
  }
  final jsonString = file.readAsStringSync();
  return indikatorResponseFromJson(jsonString);
}

class IndikatorController extends ChangeNotifier {
  List<IndikatorModel> _data = [];
  int? _selectedIndikatorId;                 // <-- add this
  String? _searchKeyword;
  int? get selectedIndikatorId => _selectedIndikatorId; // <-- and this
  
  // Loading states
  bool _isLoaded = false;
  String? _error;

  // 1. Declare the dependency reference variable
  PaketPekerjaanController? _pekerjaanController;

  // Getters
  List<IndikatorModel> get data => _data;
  bool get isLoaded => _isLoaded;
  String? get error => _error;
  bool get hasData => _data.isNotEmpty;
  int get count => _data.length;

  // Getter to securely expose the attached controller if needed elsewhere
  PaketPekerjaanController? get paketPekerjaanController => _pekerjaanController;

  IndikatorController();

  void selectIndikator(int indikatorId) {
    _selectedIndikatorId = indikatorId;
    notifyListeners(); // so the panel can re-highlight the tapped row

    _pekerjaanController?.filterByIndikatorId(indikatorId);
  }

  void searchByKeyword(String? keyword) {
    _searchKeyword = keyword;
    notifyListeners();
    _pekerjaanController?.filterByKeyword(keyword);
  }

  void clearIndikatorSelection() {
    _selectedIndikatorId = null;
    _searchKeyword = null;
    notifyListeners();
    _pekerjaanController?.filterByIndikatorId(null);
    _pekerjaanController?.clearFilters();
  }

  // 2. Add the Proxy method to handle updates from MultiProvider
  void updatePekerjaanDependency(PaketPekerjaanController newPekerjaan) {
    _pekerjaanController = newPekerjaan;
    
    // Optional placeholder loop:
    // If you need to auto-trigger actions inside Indikator whenever Pekerjaan loads,
    // you can safely evaluate it here as read-only.
    if (_pekerjaanController != null && _pekerjaanController!.isLoaded) {
      debugPrint('Pekerjaan dependency loaded successfully inside IndikatorController.');
    }
    
    notifyListeners();
  }

  // Load data only once
  Future<void> loadIndikatorData({bool forceReload = false}) async {
    if (_isLoaded && !forceReload) {
      debugPrint('Data already loaded, skipping...');
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
        '$userProfile\\AppData\\Roaming\\SatgasPRR\\monitor_bencana_d\\json_data\\get_indikator.json';

    try {
      _error = null;
      notifyListeners();

      debugPrint('Loading data from: $targetPath');
      
      IndikatorResponse result =
          await Isolate.run(() => _parseJsonIsolate(targetPath));
      
      _data = result.listIndikator;
      _isLoaded = true;

      if (_pekerjaanController != null) {
        await _pekerjaanController!.loadPaketData(forceReload: forceReload);
        //_pekerjaanController!.generateMarkers();
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoaded = false;
      notifyListeners();
      debugPrint("Error reading/parsing JSON: $e");
      rethrow;
    }
  }

  // Clear data (useful for logout or reset)
  void clearData() {
    _data = [];
    _isLoaded = false;
    _error = null;
    notifyListeners();
  }

  // Helper methods
  IndikatorModel? getIndikatorById(int id) {
    try {
      return _data.firstWhere((indikator) => indikator.id == id);
    } catch (_) {
      return null;
    }
  }

  List<IndikatorModel> getIndikatorByKode(String kode) {
    return _data.where((indikator) => indikator.kode == kode).toList();
  }

  List<IndikatorModel> searchIndikator(String query) {
    if (query.isEmpty) return _data;
    
    final lowercaseQuery = query.toLowerCase();
    return _data.where((indikator) {
      return indikator.nama.toLowerCase().contains(lowercaseQuery) ||
          indikator.kode.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }
}