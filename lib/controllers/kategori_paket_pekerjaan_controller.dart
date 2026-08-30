import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../models/kategori_paket_pekerjaan_model.dart';

List<KategoriPaketPekerjaanModel> _parseKategoriPaketPekerjaanIsolate(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    throw Exception("File not found at $filePath");
  }
  final jsonString = file.readAsStringSync();
  return kategoriPaketPekerjaanModelFromJson(jsonString);
}

class KategoriPaketPekerjaanController extends ChangeNotifier {
  List<KategoriPaketPekerjaanModel> _data = [];
  int? _selectedKategoriId;

  bool _isLoading = false;
  bool _isLoaded = false;
  String? _error;

  List<KategoriPaketPekerjaanModel> get data => _data;
  int? get selectedKategoriId => _selectedKategoriId;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  String? get error => _error;
  bool get hasData => _data.isNotEmpty;
  int get count => _data.length;

  KategoriPaketPekerjaanController();

  void selectKategori(int? id) {
    _selectedKategoriId = id;
    notifyListeners();
  }

  Future<void> loadKategoriPaketPekerjaanData({bool forceReload = false}) async {
    if (_isLoaded && !_isLoading && !forceReload) {
      debugPrint('Kategori Paket Pekerjaan data already loaded, skipping...');
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
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('Loading kategori paket pekerjaan data from: $targetPath');

      final List<KategoriPaketPekerjaanModel> result =
          await Isolate.run(() => _parseKategoriPaketPekerjaanIsolate(targetPath));

      _data = result;
      _isLoaded = true;
    } catch (e) {
      _error = e.toString();
      _isLoaded = false;
      debugPrint("Error reading/parsing Kategori Paket Pekerjaan JSON: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  KategoriPaketPekerjaanModel? getKategoriById(int id) {
    try {
      return _data.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  void clearData() {
    _data = [];
    _selectedKategoriId = null;
    _isLoaded = false;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}